import SwiftUI
import Firebase
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import MessageUI // Added for MFMailComposeViewController

// MARK: - Mail Coordinator
class MailCoordinator: NSObject, MFMailComposeViewControllerDelegate {
    static let shared = MailCoordinator()
    
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        controller.dismiss(animated: true)
    }
}

struct FriendsView: View {
    @State private var users: [UserProfile] = []
    @State private var currentUser: UserProfile?
    @State private var friends: [UserProfile] = []
    @State private var loading = true
    @State private var errorMessage: String?
    @State private var notLoggedIn = false
    @State private var sentRequests: Set<String> = []
    @State private var sendingToUser: String?
    @State private var incomingRequests: [UserProfile] = []
    @State private var outgoingRequests: [UserProfile] = []
    @State private var showingFriendDetails = false
    @State private var selectedFriend: UserProfile?
    @State private var showingRequestConfirmation = false
    @State private var lastRequestedUser: String = ""
    @State private var showingIncomingRequestAlert = false
    @State private var newIncomingRequest: UserProfile?
    
    // Search functionality states
    @State private var searchText = ""
    @State private var searchResults: [UserProfile] = []
    @State private var isSearching = false
    @State private var showingInviteSheet = false
    @State private var selectedUserToInvite: UserProfile?
    @FocusState private var isSearchFocused: Bool
    
    // Weekly Challenge states
    @State private var showingWeeklyChallenge = false
    


    private lazy var db: Firestore = {
        // Only create Firestore instance when actually needed
        // Firebase should be configured by SessionStore before this is called
        return Firestore.firestore()
    }()

    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.Colors.background
                    .ignoresSafeArea()
                
                if notLoggedIn {
                    VStack(spacing: DesignSystem.Spacing.lg) {
                        Image(systemName: "person.2")
                            .font(.system(size: UIDevice.current.userInterfaceIdiom == .pad ? 64 : 48))
                            .foregroundColor(DesignSystem.Colors.secondary)
                        
                        Text("Please Log In")
                            .font(DesignSystem.Typography.headline)
                            .fontWeight(.bold)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        
                        Text("Log in to manage your friends and see friend requests.")
                            .font(DesignSystem.Typography.bodyMedium)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(DesignSystem.Spacing.xl)
                    .iPadOptimized()
                } else if loading {
                    VStack(spacing: DesignSystem.Spacing.md) {
                        ProgressView()
                            .scaleEffect(UIDevice.current.userInterfaceIdiom == .pad ? 1.5 : 1.2)
                        Text("Loading friends...")
                            .font(DesignSystem.Typography.bodyLarge)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    .iPadOptimized()
                } else if let errorMessage = errorMessage {
                    VStack(spacing: DesignSystem.Spacing.lg) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: UIDevice.current.userInterfaceIdiom == .pad ? 64 : 48))
                            .foregroundColor(DesignSystem.Colors.secondary)
                        
                        Text("Error")
                            .font(DesignSystem.Typography.headline)
                            .fontWeight(.bold)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        
                        Text(errorMessage)
                            .font(DesignSystem.Typography.bodyMedium)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(DesignSystem.Spacing.xl)
                    .iPadOptimized()
                } else {
                    ScrollView {
                        // Header
                        VStack(spacing: DesignSystem.Spacing.sm) { // Reduced spacing for more compact design
                            HStack {
                                // Brand title - consistent with other pages
                                Text("chai finder")
                                    .font(DesignSystem.Typography.titleLarge)
                                    .fontWeight(.bold)
                                    .foregroundColor(DesignSystem.Colors.primary)
                                    .accessibilityLabel("App title: chai finder")
                                
                                Spacer()
                            }
                            
                            // Search Bar
                            searchBarSection
                        }
                        .padding(.horizontal, DesignSystem.Spacing.md)
                        .padding(.vertical, DesignSystem.Spacing.sm)
                        .background(DesignSystem.Colors.background)
                        .iPadOptimized()

                        VStack(spacing: DesignSystem.Spacing.lg) {
                            // Weekly Challenge Section
                            if let currentUser = currentUser {
                                weeklyChallengeSection
                                
                                // Incoming Friend Requests
                                if !incomingRequests.isEmpty {
                                    incomingRequestsSection
                                }
                                
                                // Outgoing Friend Requests
                                if !outgoingRequests.isEmpty {
                                    outgoingRequestsSection
                                }
                                
                                // Current Friends
                                if !(currentUser.friends?.isEmpty ?? true) {
                                    friendsSection
                                }
                            }
                            
                            // Invite Friends Section
                            inviteFriendsSection
                            
                            // People You May Know
                            if !users.isEmpty {
                                peopleYouMayKnowSection
                            }
                        }
                        .padding(DesignSystem.Spacing.lg)
                        .iPadOptimized()
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingInviteSheet) {
                if let user = selectedUserToInvite {
                    InviteUserSheet(user: user, currentUser: currentUser) {
                        // Refresh data after invitation
                        reloadData()
                    }
                }
            }
            .sheet(isPresented: $showingWeeklyChallenge) {
                WeeklyChallengeView()
            }
            .onAppear {
                print("🔄 FriendsView onAppear - users.count: \(users.count), currentUser: \(currentUser?.displayName ?? "nil")")
                
                // Check if user is authenticated before trying to load data
                guard Auth.auth().currentUser != nil else {
                    print("⚠️ User not authenticated, skipping data load")
                    return
                }
                
                // Always ensure we have data when the view appears
                if users.isEmpty || currentUser == nil {
                    print("🔄 Data is empty or missing, reloading")
                    reloadData()
                } else {
                    print("🔄 Data appears to be valid, no reload needed")
                }
                
                setupIncomingRequestsListener()
                
                // Re-apply search if there's active search text
                if !searchText.isEmpty {
                    print("🔍 Re-applying search on view appear: '\(searchText)'")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        performSearch(searchText)
                    }
                }
            }
            .sheet(isPresented: $showingFriendDetails) {
                if let friend = selectedFriend {
                    FriendDetailView(friend: friend)
                } else {
                    VStack {
                        Text("No friend selected")
                            .font(DesignSystem.Typography.bodyLarge)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        Button("Close") {
                            showingFriendDetails = false
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .padding()
                    }
                }
            }
            .onChange(of: showingFriendDetails) { newValue in
                if !newValue {
                    // Reset selectedFriend when sheet is dismissed
                    selectedFriend = nil
                }
            }
            .alert("Friend Request Sent", isPresented: $showingRequestConfirmation) {
                Button("OK") { }
            } message: {
                Text("Your friend request to \(lastRequestedUser) has been sent successfully!")
            }
            .alert("New Friend Request", isPresented: $showingIncomingRequestAlert) {
                Button("View Requests") {
                    // This will take them to the incoming requests section
                }
                Button("OK") { }
            } message: {
                if let newRequest = newIncomingRequest {
                    Text("\(newRequest.displayName) sent you a friend request!")
                } else {
                    Text("You received a new friend request!")
                }
            }
        }
        .navigationViewStyle(.stack)
        .searchBarKeyboardDismissible()
        .onAppear {
            print("🔄 FriendsView onAppear - users.count: \(users.count), currentUser: \(currentUser?.displayName ?? "nil")")
            
            // Check if user is authenticated before trying to load data
            guard Auth.auth().currentUser != nil else {
                print("⚠️ User not authenticated, skipping data load")
                return
            }
            
            // Always ensure we have data when the view appears
            if users.isEmpty || currentUser == nil {
                print("🔄 Data is empty or missing, reloading")
                reloadData()
            } else {
                print("🔄 Data appears to be valid, no reload needed")
            }
            
            setupIncomingRequestsListener()
            
            // Re-apply search if there's active search text
            if !searchText.isEmpty {
                print("🔍 Re-applying search on view appear: '\(searchText)'")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    performSearch(searchText)
                }
            }
        }
    }
    
    // MARK: - View Components
    

    
    private var incomingRequestsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Friend Requests")
                .font(DesignSystem.Typography.headline)
                .fontWeight(.bold)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            
            ForEach(incomingRequests) { user in
                incomingRequestCard(user)
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.medium)
        .shadow(
            color: DesignSystem.Shadows.small.color,
            radius: DesignSystem.Shadows.small.radius,
            x: DesignSystem.Shadows.small.x,
            y: DesignSystem.Shadows.small.y
        )
    }
    
    private func incomingRequestCard(_ user: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                profileImage(for: user)
                    .frame(width: 50, height: 50)
                
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text(user.displayName)
                        .font(DesignSystem.Typography.bodyMedium)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    
                    Text(user.email)
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                
                Spacer()
            }

            HStack(spacing: DesignSystem.Spacing.sm) {
                Button("Accept") {
                    FriendService.acceptFriendRequest(from: user.uid) { _ in
                        reloadData()
                    }
                }
                .font(DesignSystem.Typography.caption)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, minHeight: 36)
                .background(DesignSystem.Colors.primary)
                .cornerRadius(DesignSystem.CornerRadius.small)
                
                Button("Reject") {
                    FriendService.rejectFriendRequest(from: user.uid) { _ in
                        reloadData()
                    }
                }
                .font(DesignSystem.Typography.caption)
                .fontWeight(.medium)
                .foregroundColor(DesignSystem.Colors.primary)
                .frame(maxWidth: .infinity, minHeight: 36)
                .background(DesignSystem.Colors.primary.opacity(0.1))
                .cornerRadius(DesignSystem.CornerRadius.small)
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.secondary.opacity(0.05))
        .cornerRadius(DesignSystem.CornerRadius.small)
    }
    
    private var outgoingRequestsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Pending Requests")
                .font(DesignSystem.Typography.headline)
                .fontWeight(.bold)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            
            ForEach(outgoingRequests) { user in
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    HStack {
                        profileImage(for: user)
                            .frame(width: 50, height: 50)
                        
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                            Text(user.displayName)
                                .font(DesignSystem.Typography.bodyMedium)
                                .fontWeight(.semibold)
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                            
                            Text("Request sent")
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                        
                        Spacer()
                        
                        Text("Pending")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .padding(.horizontal, DesignSystem.Spacing.sm)
                            .padding(.vertical, DesignSystem.Spacing.xs)
                            .background(DesignSystem.Colors.secondary.opacity(0.1))
                            .cornerRadius(DesignSystem.CornerRadius.small)
                    }

                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Button("Cancel Request") {
                            FriendService.cancelOutgoingFriendRequest(to: user.uid) { _ in
                                reloadData()
                            }
                        }
                        .font(DesignSystem.Typography.caption)
                        .fontWeight(.medium)
                        .foregroundColor(DesignSystem.Colors.primary)
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .background(DesignSystem.Colors.primary.opacity(0.1))
                        .cornerRadius(DesignSystem.CornerRadius.small)

                        Button("Send Reminder") {
                            // Optional: future enhancement to notify user
                        }
                        .font(DesignSystem.Typography.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .background(DesignSystem.Colors.primary)
                        .cornerRadius(DesignSystem.CornerRadius.small)
                    }
                }
                .padding(DesignSystem.Spacing.md)
                .background(DesignSystem.Colors.secondary.opacity(0.05))
                .cornerRadius(DesignSystem.CornerRadius.small)
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.medium)
        .shadow(
            color: DesignSystem.Shadows.small.color,
            radius: DesignSystem.Shadows.small.radius,
            x: DesignSystem.Shadows.small.x,
            y: DesignSystem.Shadows.small.y
        )
    }
    
    private var friendsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Current Friends")
                .font(DesignSystem.Typography.headline)
                .fontWeight(.bold)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            
            let friendProfiles = users.filter { user in
                currentUser?.friends?.contains(user.uid) ?? false
            }
            
            ForEach(friendProfiles) { friend in
                Button(action: {
                    print("🔄 Friend tapped: \(friend.displayName)")
                    print("🔄 Current selectedFriend before: \(selectedFriend?.displayName ?? "nil")")
                    selectedFriend = friend
                    print("🔄 Set selectedFriend to: \(selectedFriend?.displayName ?? "nil")")
                    showingFriendDetails = true
                    print("✅ Set showingFriendDetails = true")
                }) {
                    friendCard(friend)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.medium)
        .shadow(
            color: DesignSystem.Shadows.small.color,
            radius: DesignSystem.Shadows.small.radius,
            x: DesignSystem.Shadows.small.x,
            y: DesignSystem.Shadows.small.y
        )
    }
    
    private func friendCard(_ user: UserProfile) -> some View {
        HStack {
            profileImage(for: user)
                .frame(width: 50, height: 50)
            
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(user.displayName)
                    .font(DesignSystem.Typography.bodyMedium)
                    .fontWeight(.semibold)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .lineLimit(1)
                
                Text(user.email)
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Add a chevron to indicate it's clickable
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(DesignSystem.Colors.textSecondary)
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.secondary.opacity(0.05))
        .cornerRadius(DesignSystem.CornerRadius.small)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
        .contentShape(Rectangle()) // Make the entire card tappable
    }
    
    private var inviteFriendsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Invite Friends")
                .font(DesignSystem.Typography.headline)
                .fontWeight(.bold)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            
            Button(action: inviteFriends) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16))
                    Text("Invite a Friend")
                        .font(DesignSystem.Typography.bodyMedium)
                        .fontWeight(.medium)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignSystem.Spacing.md)
                .background(DesignSystem.Colors.primary)
                .cornerRadius(DesignSystem.CornerRadius.medium)
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.medium)
        .shadow(
            color: DesignSystem.Shadows.small.color,
            radius: DesignSystem.Shadows.small.radius,
            x: DesignSystem.Shadows.small.x,
            y: DesignSystem.Shadows.small.y
        )
    }
    
    private var peopleYouMayKnowSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("People You May Know")
                .font(DesignSystem.Typography.headline)
                .fontWeight(.bold)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            
            ForEach(users) { user in
                peopleCard(user)
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.medium)
        .shadow(
            color: DesignSystem.Shadows.small.color,
            radius: DesignSystem.Shadows.small.radius,
            x: DesignSystem.Shadows.small.x,
            y: DesignSystem.Shadows.small.y
        )
    }
    
    private func peopleCard(_ user: UserProfile) -> some View {
        Button(action: {
            print("🔄 Person tapped: \(user.displayName)")
            print("🔄 Current selectedFriend before: \(selectedFriend?.displayName ?? "nil")")
            selectedFriend = user
            print("🔄 Set selectedFriend to: \(selectedFriend?.displayName ?? "nil")")
            showingFriendDetails = true
            print("✅ Set showingFriendDetails = true")
        }) {
            HStack {
                profileImage(for: user)
                    .frame(width: 50, height: 50)
                
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text(user.displayName)
                        .font(DesignSystem.Typography.bodyMedium)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    
                    Text(user.email)
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                
                Spacer()
                
                // Action area prefers horizontal layout, but will stack vertically if space is tight
                ViewThatFits(in: .horizontal) {
                    // Preferred: horizontal actions
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        if isFriend(user) {
                            Button("Remove") { removeFriend(user) }
                                .font(DesignSystem.Typography.caption)
                                .fontWeight(.medium)
                                .foregroundColor(DesignSystem.Colors.primary)
                                .padding(.horizontal, DesignSystem.Spacing.sm)
                                .padding(.vertical, DesignSystem.Spacing.xs)
                                .background(DesignSystem.Colors.primary.opacity(0.1))
                                .cornerRadius(DesignSystem.CornerRadius.small)
                                .lineLimit(1)
                        } else {
                            // Only show the Send Request button if it's not the current user
                            if currentUser?.uid != user.uid {
                                Button(action: { sendFriendRequest(to: user) }) {
                                    if sendingToUser == user.uid {
                                        ProgressView().scaleEffect(0.8)
                                    } else if sentRequests.contains(user.uid) || isRequestSent(to: user) {
                                        Text("Requested")
                                            .font(DesignSystem.Typography.caption)
                                            .foregroundColor(DesignSystem.Colors.textSecondary)
                                            .lineLimit(1)
                                    } else {
                                        VStack(spacing: 0) {
                                            Text("Send")
                                                .font(DesignSystem.Typography.caption)
                                                .fontWeight(.medium)
                                                .lineLimit(1)
                                                .allowsTightening(false)
                                            Text("Request")
                                                .font(DesignSystem.Typography.caption)
                                                .fontWeight(.medium)
                                                .lineLimit(1)
                                                .allowsTightening(false)
                                        }
                                        .multilineTextAlignment(.center)
                                        .fixedSize(horizontal: true, vertical: true)
                                    }
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, DesignSystem.Spacing.sm)
                                .padding(.vertical, DesignSystem.Spacing.xs)
                                .background(DesignSystem.Colors.primary)
                                .cornerRadius(DesignSystem.CornerRadius.small)
                                .disabled(sendingToUser != nil)
                            }
                        }
                    }
                    .layoutPriority(2)
                    
                    // Fallback: vertical actions to free horizontal space for the name
                    VStack(alignment: .trailing, spacing: DesignSystem.Spacing.xs) {
                        if isFriend(user) {
                            Button("Remove") { removeFriend(user) }
                                .font(DesignSystem.Typography.caption)
                                .fontWeight(.medium)
                                .foregroundColor(DesignSystem.Colors.primary)
                                .padding(.horizontal, DesignSystem.Spacing.sm)
                                .padding(.vertical, DesignSystem.Spacing.xs)
                                .background(DesignSystem.Colors.primary.opacity(0.1))
                                .cornerRadius(DesignSystem.CornerRadius.small)
                                .lineLimit(1)
                        } else {
                            // Only show the Send Request button if it's not the current user
                            if currentUser?.uid != user.uid {
                                Button(action: { sendFriendRequest(to: user) }) {
                                    if sendingToUser == user.uid {
                                        ProgressView().scaleEffect(0.8)
                                    } else if sentRequests.contains(user.uid) || isRequestSent(to: user) {
                                        Text("Requested")
                                            .font(DesignSystem.Typography.caption)
                                            .foregroundColor(DesignSystem.Colors.textSecondary)
                                            .lineLimit(1)
                                    } else {
                                        VStack(spacing: 0) {
                                            Text("Send")
                                                .font(DesignSystem.Typography.caption)
                                                .fontWeight(.medium)
                                                .lineLimit(1)
                                                .allowsTightening(false)
                                            Text("Request")
                                                .font(DesignSystem.Typography.caption)
                                                .fontWeight(.medium)
                                                .lineLimit(1)
                                                .allowsTightening(false)
                                        }
                                        .multilineTextAlignment(.center)
                                        .fixedSize(horizontal: true, vertical: true)
                                    }
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, DesignSystem.Spacing.sm)
                                .padding(.vertical, DesignSystem.Spacing.xs)
                                .background(DesignSystem.Colors.primary)
                                .cornerRadius(DesignSystem.CornerRadius.small)
                                .disabled(sendingToUser != nil)
                            }
                        }
                    }
                    .layoutPriority(2)
                }
                .allowsHitTesting(true) // Ensure buttons are tappable
            }
            .padding(DesignSystem.Spacing.md)
            .background(DesignSystem.Colors.secondary.opacity(0.05))
            .cornerRadius(DesignSystem.CornerRadius.small)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
            .contentShape(Rectangle()) // Make the entire card tappable
        }
        .buttonStyle(PlainButtonStyle())
        .allowsHitTesting(true) // Ensure the main button is tappable
    }

    // MARK: - Helper Functions
    
    private func setupIncomingRequestsListener() {
        // Check if Firebase is initialized before accessing Auth
        if FirebaseApp.app() == nil {
            print("⚠️ Firebase not initialized, skipping incoming requests listener")
            return
        }
        
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        print("🎧 Setting up real-time listener for incoming friend requests...")
        
        // Listen for new incoming friend requests
        Firestore.firestore().collection("users").document(currentUserId)
            .collection("incomingFriendRequests")
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("❌ Error listening for incoming requests: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                DispatchQueue.main.async {
                    let previousCount = self.incomingRequests.count
                    self.incomingRequests = documents.compactMap { doc -> UserProfile? in
                        let data = doc.data()
                        
                        // The friend request document now contains the sender's profile information
                        let uid = data["uid"] as? String ?? doc.documentID
                        let displayName = data["displayName"] as? String ?? "Unknown User"
                        let email = data["email"] as? String ?? "unknown@email.com"
                        let photoURL = data["photoURL"] as? String
                        
                        return UserProfile(
                            id: doc.documentID,
                            uid: uid,
                            displayName: displayName,
                            email: email,
                            photoURL: photoURL,
                            friends: [], // Friend requests don't have friends array
                            incomingRequests: [], // Friend requests don't have incoming requests
                            outgoingRequests: [], // Friend requests don't have outgoing requests
                            bio: nil // Friend requests don't have bio
                        )
                    }
                    
                    // Check if we have new friend requests and send notifications
                    if self.incomingRequests.count > previousCount {
                        let newRequests = self.incomingRequests.count - previousCount
                        print("📱 New friend requests detected: \(newRequests)")
                        
                        // Send notification for the most recent request
                        if let latestRequest = self.incomingRequests.last {
                            NotificationService.shared.notifyFriendRequest(fromUserName: latestRequest.displayName)
                        }
                    }
                }
            }
    }
    
    private func reloadData() {
        // Check if Firebase is initialized before accessing Auth
        if FirebaseApp.app() == nil {
            print("⚠️ Firebase not initialized, setting notLoggedIn")
            notLoggedIn = true
            loading = false
            return
        }
        
        // Check if user is authenticated
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            print("⚠️ User not authenticated in reloadData")
            notLoggedIn = true
            loading = false
            return
        }
        
        loading = true
        errorMessage = nil
        
        print("🔄 Reloading friends data for user: \(currentUserId)")
        
        // Get all users first
        Firestore.firestore().collection("users").getDocuments { snapshot, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.errorMessage = error.localizedDescription
                    self.loading = false
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    self.errorMessage = "No users found"
                    self.loading = false
                    return
                }
                
                // Parse all users
                let allUsers = documents.compactMap { doc -> UserProfile? in
                    let data = doc.data()
                    return UserProfile(
                        id: doc.documentID,
                        uid: data["uid"] as? String ?? doc.documentID,
                        displayName: data["displayName"] as? String ?? "Unknown User",
                        email: data["email"] as? String ?? "unknown",
                        photoURL: data["photoURL"] as? String,
                        friends: data["friends"] as? [String] ?? [],
                        incomingRequests: data["incomingRequests"] as? [String] ?? [],
                        outgoingRequests: data["outgoingRequests"] as? [String] ?? [],
                        bio: data["bio"] as? String
                    )
                }
                
                self.users = allUsers
                print("🔄 Loaded \(allUsers.count) total users")
                
                // Find current user
                if let currentUser = allUsers.first(where: { $0.uid == currentUserId }) {
                    self.currentUser = currentUser
                    print("🔄 Found current user: \(currentUser.displayName)")
                    print("🔄 Current user has \(currentUser.friends?.count ?? 0) friends")
                    
                    self.friends = currentUser.friends?.compactMap { friendId in
                        allUsers.first { $0.uid == friendId }
                    } ?? []
                    
                    print("🔄 Resolved \(self.friends.count) friend profiles")
                } else {
                    print("❌ Could not find current user in loaded users")
                }
                
                self.loading = false
                print("✅ Reloaded friends data: \(self.friends.count) friends, \(self.users.count) total users")
            }
        }
    }
    
    private func loadFriendRequests() {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        // Load incoming friend requests
        Firestore.firestore().collection("users").document(currentUserId)
            .collection("incomingFriendRequests")
            .getDocuments { snapshot, error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("❌ Error loading incoming requests: \(error.localizedDescription)")
                        return
                    }
                    
                    guard let documents = snapshot?.documents else { return }
                    
                    self.incomingRequests = documents.compactMap { doc -> UserProfile? in
                        let data = doc.data()
                        return UserProfile(
                            id: doc.documentID,
                            uid: data["uid"] as? String ?? doc.documentID,
                            displayName: data["displayName"] as? String ?? "Unknown User",
                            email: data["email"] as? String ?? "unknown",
                            photoURL: data["photoURL"] as? String,
                            friends: data["friends"] as? [String] ?? [],
                            incomingRequests: data["incomingRequests"] as? [String] ?? [],
                            outgoingRequests: data["outgoingRequests"] as? [String] ?? [],
                            bio: data["bio"] as? String
                        )
                    }
                    

                }
            }
        
        // Load outgoing friend requests
        loadOutgoingRequests()
    }
    
    private func loadOutgoingRequests() {
        // Check if Firebase is initialized before accessing Auth
        if FirebaseApp.app() == nil {
            print("⚠️ Firebase not initialized, skipping outgoing requests load")
            return
        }
        
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        print("📤 Loading outgoing friend requests...")
        
        // Get the current user's outgoing requests array first
        Firestore.firestore().collection("users").document(currentUserId).getDocument { userDoc, userError in
            if let userError = userError {
                print("❌ Error loading current user: \(userError.localizedDescription)")
                return
            }
            
            guard let userData = userDoc?.data(),
                  let outgoingRequestUIDs = userData["outgoingRequests"] as? [String],
                  !outgoingRequestUIDs.isEmpty else {
                print("📤 No outgoing requests found")
                DispatchQueue.main.async {
                    self.outgoingRequests = []
                }
                return
            }
            
            print("📤 Found \(outgoingRequestUIDs.count) outgoing request UIDs: \(outgoingRequestUIDs)")
            
            // Fetch the actual user profiles for the outgoing requests
            let batch = Firestore.firestore().batch()
            var userProfiles: [UserProfile] = []
            let group = DispatchGroup()
            
            for uid in outgoingRequestUIDs {
                group.enter()
                Firestore.firestore().collection("users").document(uid).getDocument { doc, error in
                    defer { group.leave() }
                    
                    if let error = error {
                        print("❌ Error loading user \(uid): \(error.localizedDescription)")
                        return
                    }
                    
                    guard let data = doc?.data() else {
                        print("❌ User document not found for \(uid)")
                        return
                    }
                    
                    let userProfile = UserProfile(
                        id: doc?.documentID,
                        uid: data["uid"] as? String ?? uid,
                        displayName: data["displayName"] as? String ?? "Unknown User",
                        email: data["email"] as? String ?? "unknown@email.com",
                        photoURL: data["photoURL"] as? String,
                        friends: data["friends"] as? [String] ?? [],
                        incomingRequests: data["incomingRequests"] as? [String] ?? [],
                        outgoingRequests: data["outgoingRequests"] as? [String] ?? [],
                        bio: data["bio"] as? String
                    )
                    
                    userProfiles.append(userProfile)
                }
            }
            
            group.notify(queue: .main) {
                print("📤 Loaded \(userProfiles.count) outgoing request profiles")
                self.outgoingRequests = userProfiles
            }
        }
    }
    
    private func isFriend(_ user: UserProfile) -> Bool {
        currentUser?.friends?.contains(user.uid) ?? false
    }

    private func isRequestSent(to user: UserProfile) -> Bool {
        // Check both outgoing requests array and current user's outgoing requests
        let isInOutgoingRequests = outgoingRequests.contains { $0.uid == user.uid }
        let isInCurrentUserArray = currentUser?.outgoingRequests?.contains(user.uid) ?? false
        
        let isSent = isInOutgoingRequests || isInCurrentUserArray
        print("🔍 Checking if request sent to \(user.displayName): \(isSent) (outgoing: \(isInOutgoingRequests), array: \(isInCurrentUserArray))")
        return isSent
    }

    private func sendFriendRequest(to user: UserProfile) {
        print("📤 Sending request to: \(user.displayName) (\(user.uid))")
        withAnimation {
            sendingToUser = user.uid
        }
        
        FriendService.sendFriendRequest(to: user.uid) { success in
            DispatchQueue.main.async {
                self.sendingToUser = nil
                if success {
                    self.sentRequests.insert(user.uid)
                    self.lastRequestedUser = user.displayName
                    self.showingRequestConfirmation = true
                    print("✅ Friend request sent successfully to \(user.displayName)!")
                    // Reload data to update the UI immediately
                    self.reloadData()
                } else {
                    print("❌ Friend request failed for \(user.displayName)")
                }
            }
        }
    }

    private func removeFriend(_ user: UserProfile) {
        guard let currentUser = currentUser else { return }

        let batch = Firestore.firestore().batch()
        let currentRef = Firestore.firestore().collection("users").document(currentUser.uid)
        let otherRef = Firestore.firestore().collection("users").document(user.uid)

        var currentFriends = Set(currentUser.friends ?? [])
        currentFriends.remove(user.uid)
        batch.updateData(["friends": Array(currentFriends)], forDocument: currentRef)

        var otherFriends = Set(user.friends ?? [])
        otherFriends.remove(currentUser.uid)
        batch.updateData(["friends": Array(otherFriends)], forDocument: otherRef)

        batch.commit { error in
            DispatchQueue.main.async {
                if error == nil {
                    self.reloadData()
                }
            }
        }
    }

    private func profileImage(for user: UserProfile) -> some View {
        let initials = user.displayName
            .split(separator: " ")
            .compactMap { $0.first }
            .prefix(2)
            .map { String($0) }
            .joined()

        return Text(initials.uppercased())
            .font(.system(size: 16, weight: .bold))
            .foregroundColor(.white)
            .frame(width: 40, height: 40)
            .background(DesignSystem.Colors.primary)
            .clipShape(Circle())
    }

    private func inviteFriends() {
        let currentUserName = currentUser?.displayName ?? "Your friend"
        
        // Create a more professional invitation
        let subject = "Join our chai-loving community with Chai Finder! 🫖"
        
        let body = """
        Hey!
        
        I've been using **Chai Finder**, a social app that connects chai lovers through shared experiences and trusted recommendations — and I think you'd love it too!
        
        🫶 What makes Chai Finder special:
        • See where your friends actually love to get chai
        • Get personalized recommendations based on your taste
        • Share your own chai ratings and comments
        • Save your favorite spots for next time
        • Connect over your love of good chai
        
        📍 It's perfect for discovering authentic chai through people you trust — whether it's cutting chai, kadak chai, or anything in between.
        
        👉 Download the app:
        **iOS App Store:** https://apps.apple.com/us/app/chai-finder/id6747459183
        
        Once you're in, add me so we can swap chai spots!
        
        Cheers to better chai,
        \(currentUserName)
        """
        
        // Check if device can send emails
        if MFMailComposeViewController.canSendMail() {
            let mailComposer = MFMailComposeViewController()
            mailComposer.mailComposeDelegate = MailCoordinator.shared
            mailComposer.setSubject(subject)
            mailComposer.setMessageBody(body, isHTML: false)
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                rootVC.present(mailComposer, animated: true)
            }
        } else {
            // Fallback to activity view controller if email is not available
            let emailContent = "Subject: \(subject)\n\n\(body)"
            let av = UIActivityViewController(activityItems: [emailContent], applicationActivities: nil)
            
            // Set the activity type to prefer email
            av.excludedActivityTypes = [
                .assignToContact,
                .addToReadingList,
                .openInIBooks,
                .markupAsPDF
            ]

            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                rootVC.present(av, animated: true)
            }
        }
    }
    
    // MARK: - Send Email to Existing User
    private func sendEmail(to user: UserProfile) {
        // Check if device can send emails
        if MFMailComposeViewController.canSendMail() {
            let mailComposer = MFMailComposeViewController()
            mailComposer.mailComposeDelegate = MailCoordinator.shared
            mailComposer.setToRecipients([user.email])
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                rootVC.present(mailComposer, animated: true)
            }
        } else {
            // Fallback to activity view controller if email is not available
            let av = UIActivityViewController(activityItems: [""], applicationActivities: nil)
            
            // Set the activity type to prefer email
            av.excludedActivityTypes = [
                .assignToContact,
                .addToReadingList,
                .openInIBooks,
                .markupAsPDF
            ]

            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                rootVC.present(av, animated: true)
            }
        }
    }
    
    // MARK: - Search Bar Section
    private var searchBarSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .font(.system(size: 14))
                    .accessibilityHidden(true)
                
                TextField("Search for users by name, email, or bio...", text: $searchText)
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .autocorrectionDisabled(true)
                    .autocapitalization(.none)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .focused($isSearchFocused)
                    .accessibilityLabel("Search for users")
                    .accessibilityHint("Type to search for users by name, email, or bio")
                    .submitLabel(.search)
                    .keyboardType(.default)
                    .textContentType(.none)
                    .onChange(of: searchText) { newValue in
                        // Debounced search
                        Task {
                            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
                            await MainActor.run {
                                if searchText == newValue {
                                    performSearch(newValue)
                                }
                            }
                        }
                    }
                    .onSubmit {
                        performSearch(searchText)
                        // Keep focus to allow continued typing
                    }
                    .onTapGesture {
                        // Show search suggestions when tapping the search field
                        if searchText.isEmpty {
                            // Could add search suggestions here
                        }
                    }
                
                if isSearching {
                    ProgressView()
                        .scaleEffect(0.8)
                        .frame(width: 28, height: 28)
                } else if !searchText.isEmpty {
                    Button(action: { 
                        withAnimation(DesignSystem.Animation.quick) {
                            searchText = ""
                            searchResults = []
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .font(.system(size: 14))
                            .frame(width: 28, height: 28)
                    }
                    .accessibilityLabel("Clear search")
                    .accessibilityHint("Double tap to clear search text")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(DesignSystem.Colors.searchBackground)
            .cornerRadius(DesignSystem.CornerRadius.medium)
            .shadow(
                color: Color.black.opacity(0.04),
                radius: 2,
                x: 0,
                y: 1
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                    .stroke(DesignSystem.Colors.border.opacity(0.08), lineWidth: 0.1)
            )
            
            // Search feedback
            if !searchText.isEmpty {
                searchFeedbackView
            }
            
            // Search suggestions (when search field is empty)
            if searchText.isEmpty {
                searchSuggestionsView
            }
            
            // Search Results
            if !searchText.isEmpty && !searchResults.isEmpty {
                searchResultsSection
            } else if !searchText.isEmpty && searchResults.isEmpty && !isSearching {
                noResultsSection
            }
        }
    }
    
    // MARK: - Search Feedback View
    private var searchFeedbackView: some View {
        HStack {
            Image(systemName: "info.circle.fill")
                .foregroundColor(DesignSystem.Colors.primary)
                .font(.system(size: 12))
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Found \(searchResults.count) results")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                
                if !searchText.isEmpty {
                    Text("Searching through \(users.count) local users + Firestore")
                        .font(DesignSystem.Typography.caption2)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }
            
            Spacer()
            
            if searchResults.count > 0 {
                Text("Tap to clear")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.primary)
                    .onTapGesture {
                        withAnimation(DesignSystem.Animation.quick) {
                            searchText = ""
                            searchResults = []
                        }
                    }
                }
            }
        .padding(.horizontal, 4)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
    
    // MARK: - Search Suggestions View
    private var searchSuggestionsView: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Search tips removed for cleaner interface
            
            // Debug info (development only)
            #if DEBUG
            HStack {
                Text("🔍 Debug:")
                    .font(DesignSystem.Typography.caption2)
                    .foregroundColor(DesignSystem.Colors.primary)
                
                Text("\(users.count) local users")
                    .font(DesignSystem.Typography.caption2)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                
                Button("Test Search") {
                    testSearchFunctionality()
                }
                .font(DesignSystem.Typography.caption2)
                .foregroundColor(DesignSystem.Colors.primary)
                .padding(.horizontal, 4)
                
                Button("Enhanced Search") {
                    let results = performLocalSearch(query: "test", searchWords: ["test"])
                    print("🧪 Enhanced search test results: \(results.count)")
                }
                .font(DesignSystem.Typography.caption2)
                .foregroundColor(DesignSystem.Colors.primary)
                .padding(.horizontal, 4)
                
                Button("Stats") {
                    let stats = getSearchStats()
                    print("🔍 FriendsView Search Stats: \(stats)")
                }
                .font(DesignSystem.Typography.caption2)
                .foregroundColor(DesignSystem.Colors.primary)
                .padding(.horizontal, 4)
            }
            .padding(.horizontal, 4)
            #endif
        }
        .padding(.top, 4)
    }
    
    // MARK: - Search Results Section
    private var searchResultsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Search Results")
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .padding(.horizontal, 4)
            
            LazyVStack(spacing: 6) {
                ForEach(searchResults) { user in
                    SearchResultRow(
                        user: user,
                        currentUser: currentUser,
                        sentRequests: sentRequests,
                        onInvite: {
                            selectedUserToInvite = user
                            showingInviteSheet = true
                        },
                        onInviteViaEmail: {
                            sendEmail(to: user)
                        },
                        onTap: {
                            selectedFriend = user
                            showingFriendDetails = true
                        }
                    )
                }
            }
        }
        .padding(.vertical, 8)
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.small)
        .shadow(
            color: Color.black.opacity(0.03),
            radius: 2,
            x: 0,
            y: 1
        )
    }
    
    // MARK: - No Results Section
    private var noResultsSection: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "person.crop.circle.badge.questionmark")
                    .foregroundColor(DesignSystem.Colors.secondary)
                    .font(.system(size: 16))
                
                Text("No users found")
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                
                Spacer()
            }
            
            Button(action: {
                // Invite by email functionality - generic invitation
                inviteFriends()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "envelope")
                        .font(.system(size: 14))
                    Text("Invite by Email")
                        .font(DesignSystem.Typography.bodySmall)
                        .fontWeight(.medium)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(DesignSystem.Colors.primary)
                .cornerRadius(DesignSystem.CornerRadius.small)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.small)
        .shadow(
            color: Color.black.opacity(0.03),
            radius: 2,
            x: 0,
            y: 1
        )
    }
    
    // MARK: - Search Functionality
    private func performSearch(_ query: String) {
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        
        print("🔍 Performing search for: '\(query)'")
        isSearching = true
        
        let queryLower = query.lowercased().trimmingCharacters(in: .whitespaces)
        let searchWords = queryLower.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        
        // Start with enhanced local search for immediate results
        let localResults = performLocalSearch(query: queryLower, searchWords: searchWords)
        searchResults = localResults
        
        // Then try enhanced search with Firestore (asynchronous)
        performEnhancedSearch(query: query)
        
        // Set a timeout to ensure search doesn't hang indefinitely
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            if self.isSearching {
                print("⚠️ Search timeout reached, stopping search")
                self.isSearching = false
            }
        }
    }
    
    /// Enhanced search that combines multiple search strategies
    private func performEnhancedSearch(query: String) -> [UserProfile] {
        let queryLower = query.lowercased().trimmingCharacters(in: .whitespaces)
        let searchWords = queryLower.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        
        // If no valid search words, return empty results
        if searchWords.isEmpty {
            return []
        }
        
        print("🔍 Search words: \(searchWords)")
        
        // Strategy 1: Local search in existing users
        let localResults = performLocalSearch(query: queryLower, searchWords: searchWords)
        print("🔍 Local search results: \(localResults.count)")
        
        // Strategy 2: Firestore search for additional users (asynchronous)
        performFirestoreSearch(query: queryLower, searchWords: searchWords)
        
        // Return local results immediately, Firestore results will be added via completion
        return localResults
    }
    
    /// Local search in existing users array with improved partial matching
    private func performLocalSearch(query: String, searchWords: [String]) -> [UserProfile] {
        let results = users.filter { user in
            // Create enhanced searchable text for the user
            let searchableText = createEnhancedSearchableText(for: user)
            
            // Check if ANY search word is found (more flexible than requiring ALL words)
            let anyWordFound = searchWords.contains { searchWord in
                searchableText.contains(searchWord)
            }
            
            // Also check for exact phrase match (higher priority)
            let exactPhraseFound = searchableText.contains(query)
            
            return anyWordFound || exactPhraseFound
        }
        
        // Filter out current user and existing connections
        let currentUserId = currentUser?.uid ?? ""
        let filteredResults = results.filter { user in
            user.uid != currentUserId &&
            !(currentUser?.friends?.contains(user.uid) ?? false) &&
            !sentRequests.contains(user.uid) &&
            !incomingRequests.contains { $0.uid == user.uid } &&
            !outgoingRequests.contains { $0.uid == user.uid }
        }
        
        // Sort by relevance
        let sortedResults = sortResultsByRelevance(filteredResults, searchWords: searchWords)
        
        return sortedResults
    }
    
    /// Create comprehensive searchable text for a user with better indexing for partial matches
    private func createEnhancedSearchableText(for user: UserProfile) -> String {
        var searchText = user.displayName.lowercased()
        searchText += " " + user.email.lowercased()
        
        // Add email parts for better matching
        let emailParts = user.email.lowercased().components(separatedBy: "@")
        if emailParts.count > 0 {
            searchText += " " + emailParts[0] // username part
        }
        
        // Add display name parts for better matching
        let nameParts = user.displayName.lowercased().components(separatedBy: " ")
        searchText += " " + nameParts.joined(separator: " ")
        
        // Add additional searchable fields if available
        if let bio = user.bio {
            searchText += " " + bio.lowercased()
        }
        
        return searchText
    }
    
    /// Enhanced Firestore search with multiple strategies for better partial matching
    private func performFirestoreSearch(query: String, searchWords: [String]) -> [UserProfile] {
        let db = Firestore.firestore()
        var results: [UserProfile] = []
        var completedQueries = 0
        let totalQueries = 3 // Increased to include more search strategies
        
        let queryLower = query.lowercased().trimmingCharacters(in: .whitespaces)
        
        // Strategy 1: Prefix search by display name (existing)
        db.collection("users")
            .whereField("displayName", isGreaterThanOrEqualTo: queryLower)
            .whereField("displayName", isLessThan: queryLower + "\u{f8ff}")
            .limit(to: 20)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ Error searching users by name prefix: \(error.localizedDescription)")
                } else if let documents = snapshot?.documents {
                    for document in documents {
                        if let userProfile = self.createUserProfile(from: document) {
                            results.append(userProfile)
                        }
                    }
                }
                
                completedQueries += 1
                if completedQueries == totalQueries {
                    self.updateSearchResults(results: results)
                }
            }
        
        // Strategy 2: Prefix search by email (existing)
        db.collection("users")
            .whereField("email", isGreaterThanOrEqualTo: queryLower)
            .whereField("email", isLessThan: queryLower + "\u{f8ff}")
            .limit(to: 20)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ Error searching users by email prefix: \(error.localizedDescription)")
                } else if let documents = snapshot?.documents {
                    for document in documents {
                        if let userProfile = self.createUserProfile(from: document) {
                            if !results.contains(where: { $0.uid == userProfile.uid }) {
                                results.append(userProfile)
                            }
                        }
                    }
                }
                
                completedQueries += 1
                if completedQueries == totalQueries {
                    self.updateSearchResults(results: results)
                }
            }
        
        // Strategy 3: Get more users and filter locally for better partial matching
        db.collection("users")
            .limit(to: 100) // Get more users for local filtering
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ Error getting users for local filtering: \(error.localizedDescription)")
                } else if let documents = snapshot?.documents {
                    for document in documents {
                        if let userProfile = self.createUserProfile(from: document) {
                            // Check if this user matches our search criteria
                            let searchableText = self.createEnhancedSearchableText(for: userProfile)
                            let anyWordFound = searchWords.contains { searchWord in
                                searchableText.contains(searchWord)
                            }
                            let exactPhraseFound = searchableText.contains(queryLower)
                            
                            if (anyWordFound || exactPhraseFound) && !results.contains(where: { $0.uid == userProfile.uid }) {
                                results.append(userProfile)
                            }
                        }
                    }
                }
                
                completedQueries += 1
                if completedQueries == totalQueries {
                    self.updateSearchResults(results: results)
                }
            }
        
        // Return empty results initially - will be updated via completion
        return []
    }
    
    /// Update search results after Firestore queries complete
    private func updateSearchResults(results: [UserProfile]) {
        // Get current search results and combine with new Firestore results
        var allResults = searchResults // Start with current results (which include local results)
        
        for firestoreUser in results {
            if !allResults.contains(where: { $0.uid == firestoreUser.uid }) {
                allResults.append(firestoreUser)
            }
        }
        
        // Filter out current user and existing connections
        let currentUserId = currentUser?.uid ?? ""
        let filteredResults = allResults.filter { user in
            user.uid != currentUserId &&
            !(currentUser?.friends?.contains(user.uid) ?? false) &&
            !sentRequests.contains(user.uid) &&
            !incomingRequests.contains { $0.uid == user.uid } &&
            !outgoingRequests.contains { $0.uid == user.uid }
        }
        
        // Sort by relevance and update UI
        let searchWords = searchText.lowercased().components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        let sortedResults = sortResultsByRelevance(filteredResults, searchWords: searchWords)
        
        DispatchQueue.main.async {
            self.searchResults = sortedResults
            self.isSearching = false
            print("🔍 Search completed: Found \(sortedResults.count) total results (local + Firestore)")
        }
    }
    
    /// Simple fallback search that only uses local data (no Firestore)
    private func performSimpleSearch(query: String) -> [UserProfile] {
        let queryLower = query.lowercased().trimmingCharacters(in: .whitespaces)
        let searchWords = queryLower.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        
        if searchWords.isEmpty {
            return []
        }
        
        print("🔍 Performing simple local search for: '\(query)'")
        
        // Only search in existing users array
        let localResults = performLocalSearch(query: queryLower, searchWords: searchWords)
        
        // Filter out current user and existing connections
        let currentUserId = currentUser?.uid ?? ""
        let filteredResults = localResults.filter { user in
            user.uid != currentUserId &&
            !(currentUser?.friends?.contains(user.uid) ?? false) &&
            !sentRequests.contains(user.uid) &&
            !incomingRequests.contains { $0.uid == user.uid } &&
            !outgoingRequests.contains { $0.uid == user.uid }
        }
        
        // Sort by relevance
        let sortedResults = sortResultsByRelevance(filteredResults, searchWords: searchWords)
        
        print("🔍 Simple search completed: Found \(sortedResults.count) results")
        return sortedResults
    }
    
    /// Sort search results by relevance
    private func sortResultsByRelevance(_ results: [UserProfile], searchWords: [String]) -> [UserProfile] {
        return results.sorted { first, second in
            let firstScore = calculateUserSearchRelevance(first, searchWords: searchWords)
            let secondScore = calculateUserSearchRelevance(second, searchWords: searchWords)
            return firstScore > secondScore
        }
    }
    
    /// Calculate search relevance score for a user with improved partial matching
    private func calculateUserSearchRelevance(_ user: UserProfile, searchWords: [String]) -> Int {
        var score = 0
        let searchText = searchWords.joined(separator: " ").lowercased()
        let displayName = user.displayName.lowercased()
        let email = user.email.lowercased()
        
        // Exact phrase matches get highest scores
        if displayName.contains(searchText) { score += 100 }
        if email.contains(searchText) { score += 80 }
        if let bio = user.bio, bio.lowercased().contains(searchText) { score += 60 }
        
        // Exact word matches get high scores
        for word in searchWords {
            if displayName.contains(word) { score += 20 }
            if email.contains(word) { score += 15 }
            if let bio = user.bio, bio.lowercased().contains(word) { score += 10 }
        }
        
        // Partial matches get lower scores
        for word in searchWords {
            // Check if word appears anywhere in the display name
            if displayName.contains(word) { score += 5 }
            
            // Check email username part
            let emailParts = email.components(separatedBy: "@")
            if emailParts.count > 0 && emailParts[0].contains(word) { score += 4 }
            
            // Check bio if available
            if let bio = user.bio, bio.lowercased().contains(word) { score += 3 }
        }
        
        // Bonus for starting with search term (prefix match)
        if displayName.hasPrefix(searchWords.first ?? "") { score += 15 }
        if email.hasPrefix(searchWords.first ?? "") { score += 10 }
        
        return score
    }
    
    /// Test search functionality for debugging
    private func testSearchFunctionality() {
        print("🧪 Testing FriendsView search functionality...")
        print("🧪 Current users count: \(users.count)")
        print("🧪 Current search results count: \(searchResults.count)")
        print("🧪 Current search text: '\(searchText)'")
        
        // Test with a simple search
        let testQuery = "test"
        print("🧪 Testing search for '\(testQuery)'")
        performSearch(testQuery)
        
        // Test with first user's name
        if let firstUser = users.first {
            let searchTerm = String(firstUser.displayName.prefix(3))
            print("🧪 Testing search for '\(searchTerm)' (first 3 chars of '\(firstUser.displayName)')")
            performSearch(searchTerm)
            
            // Test partial match in middle of name
            if firstUser.displayName.count > 4 {
                let middleTerm = String(firstUser.displayName.dropFirst(1).prefix(3))
                print("🧪 Testing partial match '\(middleTerm)' (middle chars of '\(firstUser.displayName)')")
                performSearch(middleTerm)
            }
        } else {
            print("🧪 No users available for testing")
        }
        
        // Test with empty search
        print("🧪 Testing empty search")
        performSearch("")
        
        // Test enhanced search specifically
        print("🧪 Testing enhanced local search")
        let enhancedResults = performLocalSearch(query: "test", searchWords: ["test"])
        print("🧪 Enhanced search results: \(enhancedResults.count)")
    }
    
    /// Get search statistics for debugging
    private func getSearchStats() -> [String: Any] {
        let currentUserId = currentUser?.uid ?? ""
        let friendsCount = currentUser?.friends?.count ?? 0
        let sentRequestsCount = sentRequests.count
        let incomingRequestsCount = incomingRequests.count
        let outgoingRequestsCount = outgoingRequests.count
        
        return [
            "totalUsers": users.count,
            "currentUser": currentUser?.displayName ?? "nil",
            "friendsCount": friendsCount,
            "sentRequestsCount": sentRequestsCount,
            "incomingRequestsCount": incomingRequestsCount,
            "outgoingRequestsCount": outgoingRequestsCount,
            "searchResultsCount": searchResults.count,
            "searchText": searchText,
            "isSearching": isSearching
        ]
    }
    
    private func createUserProfile(from document: QueryDocumentSnapshot) -> UserProfile? {
        let data = document.data()
        
        guard let uid = data["uid"] as? String,
              let displayName = data["displayName"] as? String,
              let email = data["email"] as? String else {
            return nil
        }
        
        let friends = data["friends"] as? [String] ?? []
        let incomingRequests = data["incomingRequests"] as? [String] ?? []
        let outgoingRequests = data["outgoingRequests"] as? [String] ?? []
        let hasTasteSetup = data["hasTasteSetup"] as? Bool ?? false
        
        return UserProfile(
            uid: uid,
            displayName: displayName,
            email: email,
            friends: friends,
            incomingRequests: incomingRequests,
            outgoingRequests: outgoingRequests,
            hasTasteSetup: hasTasteSetup
        )
    }
    
    private func inviteByEmail() {
        // Create a more comprehensive invitation sheet
        let alert = UIAlertController(
            title: "Invite Friends by Email",
            message: "Share Chai Finder with your friends! They'll be able to discover great chai spots and share their experiences.",
            preferredStyle: .alert
        )
        
        // Add email input field
        alert.addTextField { textField in
            textField.placeholder = "Enter email address"
            textField.keyboardType = .emailAddress
            textField.autocapitalizationType = .none
        }
        
        alert.addAction(UIAlertAction(title: "Send Invitation", style: .default) { _ in
            if let email = alert.textFields?.first?.text, !email.isEmpty {
                self.sendEmailInvitation(to: email)
            }
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(alert, animated: true)
        }
    }
    
    private func sendEmailInvitation(to email: String) {
        // This would integrate with the device's mail app
        // For now, we'll show a success message
        let successAlert = UIAlertController(
            title: "Invitation Sent!",
            message: "An invitation has been sent to \(email). They'll receive an email with a link to download Chai Finder.",
            preferredStyle: .alert
        )
        
        successAlert.addAction(UIAlertAction(title: "OK", style: .default))
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(successAlert, animated: true)
        }
        
        // In a real implementation, you would:
        // 1. Send an email invitation through your backend
        // 2. Track invitation status
        // 3. Provide analytics on invitation success rates
        print("📧 Email invitation would be sent to: \(email)")
    }
    
    // MARK: - Weekly Challenge Section
    private var weeklyChallengeSection: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            HStack {
                Text("🎯 Weekly Challenge")
                    .font(DesignSystem.Typography.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("View All") {
                    showingWeeklyChallenge = true
                }
                .font(DesignSystem.Typography.bodySmall)
                .foregroundColor(DesignSystem.Colors.accent)
            }
            
            // Challenge Preview Card
            Button(action: { showingWeeklyChallenge = true }) {
                HStack {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text("Current Challenge")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        
                        Text("Tap to view details")
                            .font(DesignSystem.Typography.bodyMedium)
                            .fontWeight(.medium)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16))
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                .padding(DesignSystem.Spacing.md)
                .background(DesignSystem.Colors.cardBackground)
                .cornerRadius(DesignSystem.CornerRadius.medium)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                        .stroke(DesignSystem.Colors.border, lineWidth: 1)
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .iPadCardStyle()
    }
}

// MARK: - Invite User Sheet
struct InviteUserSheet: View {
    let user: UserProfile
    let currentUser: UserProfile?
    let onComplete: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var isInviting = false
    @State private var showingSuccessAlert = false
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: DesignSystem.Spacing.lg) {
                // Header
                VStack(spacing: DesignSystem.Spacing.md) {
                    // User Avatar
                    let initials = user.displayName
                        .split(separator: " ")
                        .compactMap { $0.first }
                        .prefix(2)
                        .map { String($0) }
                        .joined()
                    
                    Text(initials.uppercased())
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 80, height: 80)
                        .background(DesignSystem.Colors.primary)
                        .clipShape(Circle())
                    
                    Text("Send Friend Request")
                        .font(DesignSystem.Typography.headline)
                        .fontWeight(.bold)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    
                    Text("Would you like to send a friend request to \(user.displayName)?")
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                    
                    Text(user.email)
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(DesignSystem.Colors.border.opacity(0.3))
                        .cornerRadius(DesignSystem.CornerRadius.small)
                }
                
                Spacer()
                
                // Action Buttons
                VStack(spacing: DesignSystem.Spacing.md) {
                    // Only show the Send Friend Request button if it's not the current user
                    if currentUser?.uid != user.uid {
                        Button(action: {
                            sendFriendRequest()
                        }) {
                            HStack(spacing: 8) {
                                if isInviting {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Image(systemName: "person.badge.plus")
                                        .font(.system(size: 16))
                                }
                                Text(isInviting ? "Sending Request..." : "Send Friend Request")
                                    .font(DesignSystem.Typography.bodyMedium)
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(DesignSystem.Colors.primary)
                            .cornerRadius(DesignSystem.CornerRadius.medium)
                        }
                        .disabled(isInviting)
                    } else {
                        // Show a message that this is the current user
                        Text("This is your profile")
                            .font(DesignSystem.Typography.bodyMedium)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(DesignSystem.Colors.border.opacity(0.3))
                            .cornerRadius(DesignSystem.CornerRadius.medium)
                    }
                    
                    Button(action: {
                        dismiss()
                    }) {
                        Text("Cancel")
                            .font(DesignSystem.Typography.bodyMedium)
                            .fontWeight(.medium)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(DesignSystem.Colors.border.opacity(0.3))
                            .cornerRadius(DesignSystem.CornerRadius.medium)
                    }
                    .disabled(isInviting)
                }
            }
            .padding(DesignSystem.Spacing.lg)
            .background(DesignSystem.Colors.background)
            .navigationBarHidden(true)
        }
        .alert("Friend Request Sent!", isPresented: $showingSuccessAlert) {
            Button("OK") {
                dismiss()
                onComplete()
            }
        } message: {
            Text("Your friend request has been sent to \(user.displayName). They'll be notified and can accept your request.")
        }
        .alert("Error", isPresented: $showingErrorAlert) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func sendFriendRequest() {
        isInviting = true
        
        FriendService.sendFriendRequest(to: user.uid) { success in
            DispatchQueue.main.async {
                isInviting = false
                
                if success {
                    showingSuccessAlert = true
                } else {
                    errorMessage = "Failed to send friend request. Please try again."
                    showingErrorAlert = true
                }
            }
        }
    }
}

// MARK: - Search Result Row
struct SearchResultRow: View {
    let user: UserProfile
    let currentUser: UserProfile?
    let sentRequests: Set<String>
    let onInvite: () -> Void
    let onInviteViaEmail: () -> Void
    let onTap: () -> Void
    
    @State private var isInviting = false
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                // User Avatar
                let initials = user.displayName
                    .split(separator: " ")
                    .compactMap { $0.first }
                    .prefix(2)
                    .map { String($0) }
                    .joined()
                
                Text(initials.uppercased())
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(DesignSystem.Colors.primary)
                    .clipShape(Circle())
                
                // User Info - Fixed width to prevent wrapping
                VStack(alignment: .leading, spacing: 2) {
                    Text(user.displayName)
                        .font(DesignSystem.Typography.bodyMedium)
                        .fontWeight(.medium)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    
                    Text(user.email)
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Action Buttons - Increased widths to prevent text wrapping
                if sentRequests.contains(user.uid) {
                    // Already sent request
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 12))
                        Text("Sent")
                            .font(DesignSystem.Typography.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(DesignSystem.Colors.border.opacity(0.3))
                    .cornerRadius(DesignSystem.CornerRadius.small)
                    .frame(width: 65) // Increased width to prevent wrapping
                } else {
                    // Action buttons - horizontal layout with increased widths
                    HStack(spacing: 6) {
                        // Send friend request - only show if it's not the current user
                        if currentUser?.uid != user.uid {
                            Button(action: {
                                sendFriendRequest()
                            }) {
                                HStack(spacing: 4) {
                                    if isInviting {
                                        ProgressView()
                                            .scaleEffect(0.6)
                                            .frame(width: 16, height: 16)
                                    } else {
                                        Image(systemName: "person.badge.plus")
                                            .font(.system(size: 12))
                                    }
                                    Text(isInviting ? "Sending..." : "Add")
                                        .font(DesignSystem.Typography.caption)
                                        .fontWeight(.medium)
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(DesignSystem.Colors.primary)
                                .cornerRadius(DesignSystem.CornerRadius.small)
                            }
                            .disabled(isInviting)
                            .frame(width: 75) // Increased width to prevent wrapping
                        }
                        
                        // Invite via Email
                        Button(action: {
                            onInviteViaEmail()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "envelope")
                                    .font(.system(size: 12))
                                Text("Email")
                                    .font(DesignSystem.Typography.caption)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(DesignSystem.Colors.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(DesignSystem.Colors.secondary.opacity(0.1))
                            .cornerRadius(DesignSystem.CornerRadius.small)
                        }
                        .disabled(isInviting)
                        .frame(width: 70) // Increased width to prevent wrapping
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(DesignSystem.Colors.cardBackground)
            .cornerRadius(DesignSystem.CornerRadius.small)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                    .stroke(DesignSystem.Colors.border.opacity(0.08), lineWidth: 0.1)
            )
        }
        .buttonStyle(PlainButtonStyle()) // Prevents button styling from interfering
    }
    
    private func sendFriendRequest() {
        guard let currentUserId = currentUser?.uid else { return }
        
        isInviting = true
        
        FriendService.sendFriendRequest(to: user.uid) { success in
            DispatchQueue.main.async {
                isInviting = false
                
                if success {
                    // Call the onInvite callback to refresh the parent view
                    onInvite()
                }
            }
        }
    }
} 