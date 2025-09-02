import SwiftUI
import Firebase
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import MessageUI

// MARK: - Mail Coordinator
class MailCoordinator: NSObject, MFMailComposeViewControllerDelegate {
    static let shared = MailCoordinator()
    
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        controller.dismiss(animated: true)
    }
}

struct FriendsView: View {
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
    @State private var showingLeaderboard = false
    
    // Leaderboard states
    @StateObject private var leaderboardViewModel = LeaderboardViewModel()
    @State private var userRank: Int = 0
    @State private var topLeaders: [LeaderboardEntry] = []

    private lazy var db: Firestore = {
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
                        
                        Button("Retry") {
                            reloadData()
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                    .padding(DesignSystem.Spacing.xl)
                    .iPadOptimized()
                } else {
                    ScrollView {
                        VStack(spacing: DesignSystem.Spacing.lg) {
                            // Weekly Challenge Section
                            if let currentUser = currentUser {
                                weeklyChallengeSection
                                
                                // Leaderboard Section
                                leaderboardSection
                            }
                            
                            // Search Section
                            searchSection
                            
                            // Friend Requests Section
                            if !incomingRequests.isEmpty {
                                incomingRequestsSection
                            }
                            
                            // Friends Section
                            if !friends.isEmpty {
                                friendsSection
                            }
                            
                            // Invite Friends Section
                            inviteFriendsSection
                        }
                        .padding(DesignSystem.Spacing.lg)
                    }
                }
            }
            .navigationTitle("Friends")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingWeeklyChallenge) {
                WeeklyChallengeView()
            }
            .sheet(isPresented: $showingLeaderboard) {
                LeaderboardView()
            }
            .onAppear {
                print("🔄 FriendsView onAppear - currentUser: \(currentUser?.displayName ?? "nil")")
                
                guard Auth.auth().currentUser != nil else {
                    print("⚠️ User not authenticated, skipping data load")
                    return
                }
                
                if currentUser == nil {
                    print("🔄 Data is empty or missing, reloading")
                    reloadData()
                } else {
                    print("🔄 Data appears to be valid, no reload needed")
                }
                
                setupIncomingRequestsListener()
                
                if !searchText.isEmpty {
                    print("🔍 Re-applying search on view appear: '\(searchText)'")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        performSearch(searchText)
                    }
                }
                
                loadLeaderboardData()
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
    }
    
    // MARK: - View Components
    
    private var searchSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Find Friends")
                .font(DesignSystem.Typography.headline)
                .fontWeight(.bold)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                
                TextField("Search by name or email...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .focused($isSearchFocused)
                    .onChange(of: searchText) { newValue in
                        if newValue.isEmpty {
                            searchResults = []
                            isSearching = false
                        } else {
                            performSearch(newValue)
                        }
                    }
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                        searchResults = []
                        isSearching = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                }
            }
            .padding(DesignSystem.Spacing.md)
            .background(DesignSystem.Colors.cardBackground)
            .cornerRadius(DesignSystem.CornerRadius.medium)
            
            if isSearching {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Searching...")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }
            
            if !searchResults.isEmpty {
                searchResultsSection
            } else if !searchText.isEmpty && !isSearching {
                noResultsSection
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
    
    private var friendsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Friends")
                .font(DesignSystem.Typography.headline)
                .fontWeight(.bold)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            
            ForEach(friends) { friend in
                friendCard(friend)
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
        Button(action: {
            selectedFriend = user
            showingFriendDetails = true
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
                    
                    Text(user.email)
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
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
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
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
                        
                        Text("Discover new chai spots this week!")
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
    
    // MARK: - Leaderboard Section
    private var leaderboardSection: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            HStack {
                Text("🏆 Leaderboard")
                    .font(DesignSystem.Typography.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("View All") {
                    showingLeaderboard = true
                }
                .font(DesignSystem.Typography.bodySmall)
                .foregroundColor(DesignSystem.Colors.accent)
                
                Button(action: {
                    loadLeaderboardData()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14))
                        .foregroundColor(DesignSystem.Colors.accent)
                }
            }
            
            // Leaderboard Preview Card
            Button(action: { showingLeaderboard = true }) {
                VStack(spacing: DesignSystem.Spacing.sm) {
                    // User's Rank Section
                    HStack {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                            Text("Your Rank")
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                            
                            Text("#\(userRank)")
                                .font(DesignSystem.Typography.titleLarge)
                                .fontWeight(.bold)
                                .foregroundColor(DesignSystem.Colors.primary)
                        }
                        
                        Spacer()
                        
                        // Top 3 Leaders
                        VStack(alignment: .trailing, spacing: DesignSystem.Spacing.xs) {
                            Text("Top Leaders")
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                            
                            HStack(spacing: DesignSystem.Spacing.xs) {
                                ForEach(Array(topLeaders.prefix(3).enumerated()), id: \.element.id) { index, leader in
                                    VStack(spacing: 2) {
                                        Text("\(index + 1)")
                                            .font(DesignSystem.Typography.caption2)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                            .frame(width: 16, height: 16)
                                            .background(rankColor(for: index + 1))
                                            .clipShape(Circle())
                                        
                                        Text(leader.username.prefix(1).uppercased())
                                            .font(DesignSystem.Typography.caption2)
                                            .foregroundColor(DesignSystem.Colors.textSecondary)
                                    }
                                }
                            }
                        }
                    }
                    
                    // Divider
                    if !topLeaders.isEmpty {
                        Divider()
                            .background(DesignSystem.Colors.border.opacity(0.3))
                    }
                    
                    // Top 5 List
                    if !topLeaders.isEmpty {
                        VStack(spacing: DesignSystem.Spacing.xs) {
                            ForEach(Array(topLeaders.enumerated()), id: \.element.id) { index, leader in
                                HStack {
                                    Text("\(index + 1)")
                                        .font(DesignSystem.Typography.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(rankColor(for: index + 1))
                                        .frame(width: 20)
                                    
                                    Text(leader.username)
                                        .font(DesignSystem.Typography.caption)
                                        .foregroundColor(DesignSystem.Colors.textPrimary)
                                        .lineLimit(1)
                                    
                                    Spacer()
                                    
                                    Text("\(leader.totalScore) pts")
                                        .font(DesignSystem.Typography.caption)
                                        .foregroundColor(DesignSystem.Colors.textSecondary)
                                }
                            }
                        }
                    } else {
                        // Loading or empty state
                        HStack {
                            Text("Loading leaderboard...")
                                .font(DesignSystem.Typography.bodyMedium)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 16))
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                    }
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
        .onAppear {
            loadLeaderboardData()
        }
    }
    
    // MARK: - Helper Functions
    
    private func setupIncomingRequestsListener() {
        if FirebaseApp.app() == nil {
            print("⚠️ Firebase not initialized, skipping incoming requests listener")
            return
        }
        
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        print("🎧 Setting up real-time listener for incoming friend requests...")
        
        Firestore.firestore().collection("users").document(currentUserId)
            .collection("incomingFriendRequests")
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("❌ Error listening for incoming requests: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("📭 No incoming requests found")
                    return
                }
                
                print("📨 Found \(documents.count) incoming friend requests")
                
                let requests = documents.compactMap { doc -> UserProfile? in
                    let data = doc.data()
                    
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
                        friends: [],
                        incomingRequests: [],
                        outgoingRequests: [],
                        bio: nil
                    )
                }
                
                DispatchQueue.main.async {
                    self.incomingRequests = requests
                    print("✅ Updated incoming requests: \(requests.count) requests")
                }
            }
    }
    
    private func reloadData() {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            print("❌ No authenticated user found")
            return
        }
        
        print("🔄 Reloading friends data for user: \(currentUserId)")
        
        Firestore.firestore().collection("users").document(currentUserId).getDocument { snapshot, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Error loading current user: \(error.localizedDescription)")
                    self.errorMessage = "Failed to load user data: \(error.localizedDescription)"
                    self.loading = false
                    return
                }
                
                guard let data = snapshot?.data() else {
                    self.errorMessage = "Current user not found"
                    self.loading = false
                    return
                }
                
                let currentUser = UserProfile(
                    id: snapshot?.documentID,
                    uid: data["uid"] as? String ?? currentUserId,
                    displayName: data["displayName"] as? String ?? "Unknown User",
                    email: data["email"] as? String ?? "unknown",
                    photoURL: data["photoURL"] as? String,
                    friends: data["friends"] as? [String] ?? [],
                    incomingRequests: data["incomingRequests"] as? [String] ?? [],
                    outgoingRequests: data["outgoingRequests"] as? [String] ?? [],
                    bio: data["bio"] as? String
                )
                
                self.currentUser = currentUser
                print("🔄 Found current user: \(currentUser.displayName)")
                print("🔄 Current user has \(currentUser.friends?.count ?? 0) friends")
                
                self.loadFriendProfiles(friendIds: currentUser.friends ?? [])
                self.loadFriendRequests()
                
                self.loading = false
                print("✅ Reloaded friends data: \(self.friends.count) friends")
            }
        }
    }
    
    private func loadFriendProfiles(friendIds: [String]) {
        guard !friendIds.isEmpty else {
            self.friends = []
            return
        }
        
        print("👥 Loading \(friendIds.count) friend profiles...")
        
        let group = DispatchGroup()
        var friendProfiles: [UserProfile] = []
        
        for friendId in friendIds {
            group.enter()
            Firestore.firestore().collection("users").document(friendId).getDocument { doc, error in
                defer { group.leave() }
                
                if let error = error {
                    print("❌ Error loading friend \(friendId): \(error.localizedDescription)")
                    return
                }
                
                guard let data = doc?.data() else {
                    print("❌ Friend document not found for \(friendId)")
                    return
                }
                
                let friendProfile = UserProfile(
                    id: doc?.documentID,
                    uid: data["uid"] as? String ?? friendId,
                    displayName: data["displayName"] as? String ?? "Unknown User",
                    email: data["email"] as? String ?? "unknown@email.com",
                    photoURL: data["photoURL"] as? String,
                    friends: data["friends"] as? [String] ?? [],
                    incomingRequests: data["incomingRequests"] as? [String] ?? [],
                    outgoingRequests: data["outgoingRequests"] as? [String] ?? [],
                    bio: data["bio"] as? String
                )
                
                friendProfiles.append(friendProfile)
            }
        }
        
        group.notify(queue: .main) {
            print("👥 Loaded \(friendProfiles.count) friend profiles")
            self.friends = friendProfiles
        }
    }
    
    private func loadFriendRequests() {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        print("📨 Loading friend requests...")
        
        Firestore.firestore().collection("users").document(currentUserId)
            .collection("incomingFriendRequests")
            .getDocuments { snapshot, error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("❌ Error loading friend requests: \(error.localizedDescription)")
                        return
                    }
                    
                    guard let documents = snapshot?.documents else {
                        print("📭 No friend requests found")
                        return
                    }
                    
                    self.incomingRequests = documents.compactMap { doc -> UserProfile? in
                        let data = doc.data()
                        
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
                            friends: [],
                            incomingRequests: [],
                            outgoingRequests: [],
                            bio: nil
                        )
                    }
                    
                    print("✅ Loaded \(self.incomingRequests.count) friend requests")
                }
            }
    }
    
    private func performSearch(_ query: String) {
        let queryLower = query.lowercased().trimmingCharacters(in: .whitespaces)
        let searchWords = queryLower.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        
        // Don't search if query is too short
        guard queryLower.count >= 2 else {
            searchResults = []
            isSearching = false
            return
        }
        
        isSearching = true
        
        // Try Firestore search first
        performFirestoreSearch(query: queryLower, searchWords: searchWords)
        
        // If Firestore search doesn't return good results, try local search as fallback
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if self.searchResults.count < 3 && self.isSearching {
                print("🔍 Firestore search returned few results, trying local search...")
                self.performLocalSearch(query: queryLower, searchWords: searchWords)
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            if self.isSearching {
                print("⏰ Search timeout reached")
                self.isSearching = false
            }
        }
    }
    
    private func performLocalSearch(query: String, searchWords: [String]) {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        print("🔍 Performing local search for: '\(query)'")
        
        // Get all users and filter locally
        let db = Firestore.firestore()
        let usersRef = db.collection("users")
        
        usersRef.getDocuments { snapshot, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Local search error: \(error.localizedDescription)")
                    self.isSearching = false
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    self.isSearching = false
                    return
                }
                
                let allUsers = documents.compactMap { doc -> UserProfile? in
                    let data = doc.data()
                    let uid = data["uid"] as? String ?? doc.documentID
                    
                    // Skip current user
                    if uid == currentUserId {
                        return nil
                    }
                    
                    return UserProfile(
                        id: doc.documentID,
                        uid: uid,
                        displayName: data["displayName"] as? String ?? "Unknown User",
                        email: data["email"] as? String ?? "unknown@email.com",
                        photoURL: data["photoURL"] as? String,
                        friends: [],
                        incomingRequests: [],
                        outgoingRequests: [],
                        bio: nil
                    )
                }
                
                // Filter users based on search query
                let filteredUsers = allUsers.filter { user in
                    let displayName = user.displayName.lowercased()
                    let email = user.email.lowercased()
                    
                    // Check if any search word matches
                    return searchWords.contains { word in
                        displayName.contains(word) || email.contains(word)
                    }
                }
                
                // Remove users that are already friends or have pending requests
                let finalResults = filteredUsers.filter { user in
                    !(self.currentUser?.friends?.contains(user.uid) ?? false) &&
                    !self.sentRequests.contains(user.uid) &&
                    !self.incomingRequests.contains(where: { $0.uid == user.uid }) &&
                    !self.outgoingRequests.contains(where: { $0.uid == user.uid })
                }
                
                // Sort by relevance
                let sortedResults = self.sortResultsByRelevance(finalResults, searchWords: searchWords)
                
                self.searchResults = sortedResults
                self.isSearching = false
                print("🔍 Local search completed with \(sortedResults.count) results")
            }
        }
    }
    
    private func performFirestoreSearch(query: String, searchWords: [String]) {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        print("🔍 Searching Firestore for: '\(query)'")
        
        let db = Firestore.firestore()
        let usersRef = db.collection("users")
        
        // Use a more flexible search approach
        let searchTerm = searchWords.first ?? query
        
        // Strategy 1: Display name search (case-insensitive)
        let displayNameQuery = usersRef.whereField("displayName", isGreaterThanOrEqualTo: searchTerm)
            .whereField("displayName", isLessThan: searchTerm + "\u{f8ff}")
            .limit(to: 20)
        
        // Strategy 2: Email search (case-insensitive)
        let emailQuery = usersRef.whereField("email", isGreaterThanOrEqualTo: searchTerm)
            .whereField("email", isLessThan: searchTerm + "\u{f8ff}")
            .limit(to: 20)
        
        // Strategy 3: Display name search with different case
        let displayNameUpperQuery = usersRef.whereField("displayName", isGreaterThanOrEqualTo: searchTerm.uppercased())
            .whereField("displayName", isLessThan: searchTerm.uppercased() + "\u{f8ff}")
            .limit(to: 20)
        
        let group = DispatchGroup()
        var allResults: [UserProfile] = []
        
        // Search by display name
        group.enter()
        displayNameQuery.getDocuments { snapshot, error in
            defer { group.leave() }
            
            if let error = error {
                print("❌ Display name search error: \(error.localizedDescription)")
                return
            }
            
            let results = self.processSearchResults(snapshot?.documents ?? [], currentUserId: currentUserId)
            allResults.append(contentsOf: results)
        }
        
        // Search by email
        group.enter()
        emailQuery.getDocuments { snapshot, error in
            defer { group.leave() }
            
            if let error = error {
                print("❌ Email search error: \(error.localizedDescription)")
                return
            }
            
            let results = self.processSearchResults(snapshot?.documents ?? [], currentUserId: currentUserId)
            allResults.append(contentsOf: results)
        }
        
        // Search by display name uppercase
        group.enter()
        displayNameUpperQuery.getDocuments { snapshot, error in
            defer { group.leave() }
            
            if let error = error {
                print("❌ Display name uppercase search error: \(error.localizedDescription)")
                return
            }
            
            let results = self.processSearchResults(snapshot?.documents ?? [], currentUserId: currentUserId)
            allResults.append(contentsOf: results)
        }
        
        group.notify(queue: .main) {
            // Remove duplicates based on UID
            var uniqueResults: [UserProfile] = []
            var seenUIDs: Set<String> = []
            
            for result in allResults {
                if !seenUIDs.contains(result.uid) {
                    seenUIDs.insert(result.uid)
                    uniqueResults.append(result)
                }
            }
            
            // Sort by relevance
            let sortedResults = self.sortResultsByRelevance(uniqueResults, searchWords: searchWords)
            
            self.searchResults = sortedResults
            self.isSearching = false
            print("🔍 Search completed with \(sortedResults.count) results")
        }
    }
    
    private func processSearchResults(_ documents: [QueryDocumentSnapshot], currentUserId: String) -> [UserProfile] {
        return documents.compactMap { doc -> UserProfile? in
            let data = doc.data()
            let uid = data["uid"] as? String ?? doc.documentID
            
            // Skip current user
            if uid == currentUserId {
                return nil
            }
            
            // Skip if already friends
            if self.currentUser?.friends?.contains(uid) == true {
                return nil
            }
            
            // Skip if request already sent
            if self.sentRequests.contains(uid) {
                return nil
            }
            
            // Skip if incoming request exists
            if self.incomingRequests.contains(where: { $0.uid == uid }) {
                return nil
            }
            
            // Skip if outgoing request exists
            if self.outgoingRequests.contains(where: { $0.uid == uid }) {
                return nil
            }
            
            return UserProfile(
                id: doc.documentID,
                uid: uid,
                displayName: data["displayName"] as? String ?? "Unknown User",
                email: data["email"] as? String ?? "unknown@email.com",
                photoURL: data["photoURL"] as? String,
                friends: [],
                incomingRequests: [],
                outgoingRequests: [],
                bio: nil
            )
        }
    }
    
    private func sortResultsByRelevance(_ results: [UserProfile], searchWords: [String]) -> [UserProfile] {
        return results.sorted { first, second in
            let firstScore = calculateUserSearchRelevance(first, searchWords: searchWords)
            let secondScore = calculateUserSearchRelevance(second, searchWords: searchWords)
            return firstScore > secondScore
        }
    }
    
    private func calculateUserSearchRelevance(_ user: UserProfile, searchWords: [String]) -> Int {
        var score = 0
        let searchText = searchWords.joined(separator: " ").lowercased()
        let displayName = user.displayName.lowercased()
        let email = user.email.lowercased()
        
        // Exact phrase matches get highest scores
        if displayName.contains(searchText) { score += 100 }
        if email.contains(searchText) { score += 80 }
        
        // Exact word matches get high scores
        for word in searchWords {
            if displayName.contains(word) { score += 20 }
            if email.contains(word) { score += 15 }
        }
        
        // Bonus for starting with search term (prefix match)
        if displayName.hasPrefix(searchWords.first ?? "") { score += 25 }
        if email.hasPrefix(searchWords.first ?? "") { score += 20 }
        
        // Partial matches get lower scores
        for word in searchWords {
            if displayName.contains(word) { score += 5 }
            
            // Check email username part
            let emailParts = email.components(separatedBy: "@")
            if emailParts.count > 0 && emailParts[0].contains(word) { score += 8 }
        }
        
        // Bonus for shorter names (more likely to be exact matches)
        if displayName.count <= searchText.count + 3 { score += 10 }
        
        // Bonus for email username matches
        let emailUsername = email.components(separatedBy: "@").first ?? ""
        if emailUsername.contains(searchText) { score += 15 }
        
        return score
    }
    
    private func rankColor(for rank: Int) -> Color {
        switch rank {
        case 1: return .yellow // Gold
        case 2: return Color(red: 0.75, green: 0.75, blue: 0.75) // Silver
        case 3: return Color(red: 0.8, green: 0.5, blue: 0.2) // Bronze
        default: return DesignSystem.Colors.primary
        }
    }
    
    private func profileImage(for user: UserProfile) -> some View {
        Group {
            if let photoURL = user.photoURL, !photoURL.isEmpty {
                AsyncImage(url: URL(string: photoURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Text(user.displayName.prefix(1).uppercased())
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(DesignSystem.Colors.primary)
                }
                .frame(width: 50, height: 50)
                .clipShape(Circle())
            } else {
                Text(user.displayName.prefix(1).uppercased())
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(DesignSystem.Colors.primary)
                    .clipShape(Circle())
            }
        }
    }
    
    private func inviteFriends() {
        let shareText = "Join me on ChaiSpot! Download the app and let's discover great chai spots together."
        let activityVC = UIActivityViewController(activityItems: [shareText], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityVC, animated: true)
        }
    }
    
    private func sendEmail(to user: UserProfile) {
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
            mailComposer.setToRecipients([user.email])
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
    
    private func loadLeaderboardData() {
        Task {
            leaderboardViewModel.loadLeaderboard()
            
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            
            await MainActor.run {
                if let currentUserId = Auth.auth().currentUser?.uid,
                   let userEntry = leaderboardViewModel.leaderboardEntries.first(where: { $0.userId == currentUserId }) {
                    userRank = userEntry.rank
                }
                
                topLeaders = Array(leaderboardViewModel.leaderboardEntries.prefix(5))
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
                
                if sentRequests.contains(user.uid) {
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
                    .frame(width: 65)
                } else {
                    HStack(spacing: 6) {
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
                            .frame(width: 75)
                        }
                        
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
                        .frame(width: 70)
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
        .buttonStyle(PlainButtonStyle())
    }
    
    private func sendFriendRequest() {
        isInviting = true
        
        FriendService.sendFriendRequest(to: user.uid) { success in
            DispatchQueue.main.async {
                isInviting = false
                
                if success {
                    onInvite()
                }
            }
        }
    }
} 