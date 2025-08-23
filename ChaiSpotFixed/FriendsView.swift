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
                        VStack(spacing: DesignSystem.Spacing.md) {
                            Text("Social")
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Text("chai finder")
                                .font(DesignSystem.Typography.titleLarge)
                                .fontWeight(.bold)
                                .foregroundColor(DesignSystem.Colors.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(DesignSystem.Spacing.lg)
                        .background(DesignSystem.Colors.background)
                        .iPadOptimized()

                        VStack(spacing: DesignSystem.Spacing.lg) {
                            // My Profile Section
                            if let currentUser = currentUser {
                                myProfileSection(currentUser)
                                
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
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) {
                        Image("AppLogo")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 24)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        Text("Friends")
                            .font(DesignSystem.Typography.titleMedium)
                            .fontWeight(.bold)
                    }
                }
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
    }
    
    // MARK: - View Components
    
    private func myProfileSection(_ user: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("My Profile")
                .font(DesignSystem.Typography.headline)
                .fontWeight(.bold)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            
            HStack {
                profileImage(for: user)
                    .frame(width: 60, height: 60)
                
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text(user.displayName)
                        .font(DesignSystem.Typography.bodyLarge)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    
                    Text(user.email)
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                
                Spacer()
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
        Firestore.firestore().collection("users").document(currentUserId)
            .collection("outgoingFriendRequests")
            .getDocuments { snapshot, error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("❌ Error loading outgoing requests: \(error.localizedDescription)")
                        return
                    }
                    
                    guard let documents = snapshot?.documents else { return }
                    
                    self.outgoingRequests = documents.compactMap { doc -> UserProfile? in
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
} 