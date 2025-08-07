import SwiftUI
import Firebase
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
    
    // Add state to track if data has been loaded
    @State private var hasLoadedData = false

    private let db = Firestore.firestore()

    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.Colors.background
                    .ignoresSafeArea()
                
                if notLoggedIn {
                    VStack(spacing: DesignSystem.Spacing.lg) {
                        Image(systemName: "person.2")
                            .font(.system(size: 48))
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
                } else if loading {
                    VStack {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Loading friends...")
                            .font(DesignSystem.Typography.bodyLarge)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .padding(.top, DesignSystem.Spacing.md)
                    }
                } else if let errorMessage = errorMessage {
                    VStack(spacing: DesignSystem.Spacing.lg) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
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
                } else {
                    ScrollView {
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
                    }
                }
            }
            .navigationTitle("Friends")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                if !hasLoadedData {
                    reloadData()
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
            
            HStack(spacing: DesignSystem.Spacing.sm) {
                Button("Accept") {
                    FriendService.acceptFriendRequest(from: user.uid) { _ in
                        reloadData()
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                
                Button("Reject") {
                    FriendService.rejectFriendRequest(from: user.uid) { _ in
                        reloadData()
                    }
                }
                .buttonStyle(SecondaryButtonStyle())
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
                
                Text(user.email)
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
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
                    
                    Text(user.email)
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                
                Spacer()
                
                // Add a chevron to indicate it's clickable
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                
                // Action buttons in a separate HStack to prevent tap interference
                HStack(spacing: DesignSystem.Spacing.xs) {
                    if isFriend(user) {
                        Button("Remove") {
                            removeFriend(user)
                        }
                        .buttonStyle(SecondaryButtonStyle())
                    } else {
                        Button(action: {
                            sendFriendRequest(to: user)
                        }) {
                            if sendingToUser == user.uid {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else if sentRequests.contains(user.uid) || isRequestSent(to: user) {
                                Text("Requested")
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                            } else {
                                Text("Send Request")
                                    .font(DesignSystem.Typography.bodySmall)
                                    .fontWeight(.medium)
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(sendingToUser != nil)
                    }
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
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        print("🎧 Setting up real-time listener for incoming friend requests...")
        
        // Listen for new incoming friend requests
        db.collection("users").document(currentUserId)
            .collection("incomingFriendRequests")
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("❌ Error listening for incoming requests: \(error.localizedDescription)")
                    return
                }
                
                guard let snapshot = snapshot else { return }
                
                // Check for new documents
                let newDocuments = snapshot.documentChanges.filter { $0.type == .added }
                
                for change in newDocuments {
                    let senderUID = change.document.documentID
                    print("🎉 New friend request received from: \(senderUID)")
                    
                    // Find the user profile for this sender
                    if let senderUser = self.users.first(where: { $0.uid == senderUID }) {
                        DispatchQueue.main.async {
                            self.newIncomingRequest = senderUser
                            self.showingIncomingRequestAlert = true
                            print("🎉 New friend request alert shown for: \(senderUser.displayName)")
                        }
                    }
                }
            }
    }
    
    private func reloadData() {
        print("🔄 Reloading FriendsView data...")
        guard let uid = Auth.auth().currentUser?.uid else {
            notLoggedIn = true
            loading = false
            return
        }

        // Use getDocuments instead of addSnapshotListener to avoid continuous updates
        db.collection("users").getDocuments { snapshot, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Error loading users: \(error.localizedDescription)")
                    self.errorMessage = error.localizedDescription
                    self.loading = false
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("❌ No user documents found")
                    self.errorMessage = "No users found"
                    self.loading = false
                    return
                }

                let allUsers = documents.compactMap { doc -> UserProfile? in
                    let data = doc.data()
                    let uid = data["uid"] as? String ?? doc.documentID
                    let displayName = data["displayName"] as? String ?? "Unknown User"
                    let email = data["email"] as? String ?? "unknown"
                    let photoURL = data["photoURL"] as? String
                    let friends = data["friends"] as? [String] ?? []
                    let incomingRequests = data["incomingRequests"] as? [String] ?? []
                    let outgoingRequests = data["outgoingRequests"] as? [String] ?? []
                    let bio = data["bio"] as? String
                    
                    return UserProfile(
                        id: doc.documentID,
                        uid: uid,
                        displayName: displayName,
                        email: email,
                        photoURL: photoURL,
                        friends: friends,
                        incomingRequests: incomingRequests,
                        outgoingRequests: outgoingRequests,
                        bio: bio
                    )
                }

                self.currentUser = allUsers.first(where: { $0.uid == uid })
                self.users = allUsers.filter { $0.uid != uid }
                
                print("📄 Loaded \(self.users.count) users (excluding current user)")
                print("👤 Current user: \(self.currentUser?.displayName ?? "Unknown")")
                
                // Load friend requests
                self.loadFriendRequests()
                
                self.loading = false
                self.hasLoadedData = true
            }
        }
    }
    
    private func loadFriendRequests() {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        print("🔄 Loading friend requests for user: \(currentUserId)")
        
        // Use getDocuments instead of addSnapshotListener for better performance
        let group = DispatchGroup()
        
        // Load incoming requests
        group.enter()
        db.collection("users").document(currentUserId)
            .collection("incomingFriendRequests")
            .getDocuments { snapshot, error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("❌ Error loading incoming requests: \(error.localizedDescription)")
                    } else {
                        let documents = snapshot?.documents ?? []
                        let requestIds = documents.map { $0.documentID }
                        print("📄 Found \(requestIds.count) incoming requests: \(requestIds)")
                        self.incomingRequests = self.users.filter { requestIds.contains($0.uid) }
                        print("✅ Loaded \(self.incomingRequests.count) incoming request profiles")
                    }
                    group.leave()
                }
            }
        
        // Load outgoing requests
        group.enter()
        db.collection("users").document(currentUserId)
            .collection("outgoingFriendRequests")
            .getDocuments { snapshot, error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("❌ Error loading outgoing requests: \(error.localizedDescription)")
                    } else {
                        let documents = snapshot?.documents ?? []
                        let requestIds = documents.map { $0.documentID }
                        print("📄 Found \(requestIds.count) outgoing requests: \(requestIds)")
                        self.outgoingRequests = self.users.filter { requestIds.contains($0.uid) }
                        print("✅ Loaded \(self.outgoingRequests.count) outgoing request profiles")
                    }
                    group.leave()
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

        let batch = db.batch()
        let currentRef = db.collection("users").document(currentUser.uid)
        let otherRef = db.collection("users").document(user.uid)

        var currentFriends = Set(currentUser.friends ?? [])
        currentFriends.remove(user.uid)
        batch.updateData(["friends": Array(currentFriends)], forDocument: currentRef)

        var otherFriends = Set(user.friends ?? [])
        otherFriends.remove(currentUser.uid)
        batch.updateData(["friends": Array(otherFriends)], forDocument: otherRef)

        batch.commit { error in
            if error == nil {
                self.reloadData()
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
        let subject = "Find the best Desi chai near you with Chai Finder! 🫖"
        
        let body = """
        Hey!
        
        I've been using **Chai Finder**, an app that helps you discover and rate the best Desi chai spots nearby — and I think you'd love it too!
        
        🫶 What makes Chai Finder special:
        • Find authentic chai spots shared by real chai lovers
        • See friends' reviews and top picks
        • Share your own chai ratings and comments
        • Save your favorite spots for next time
        • Connect over your love of good chai
        
        📍 It's perfect for finding a new favorite cup — whether it's cutting chai, kadak chai, or anything in between.
        
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