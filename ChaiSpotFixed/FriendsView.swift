import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseFirestoreSwift

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
            .onAppear(perform: reloadData)
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
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.secondary.opacity(0.05))
        .cornerRadius(DesignSystem.CornerRadius.small)
    }

    // MARK: - Helper Functions
    
    private func reloadData() {
        print("🔄 Reloading FriendsView data...")
        guard let uid = Auth.auth().currentUser?.uid else {
            notLoggedIn = true
            loading = false
            return
        }

        // Load all users
        db.collection("users").addSnapshotListener { snapshot, error in
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
                var user = try? doc.data(as: UserProfile.self)
                user?.id = doc.documentID
                user?.uid = doc.get("uid") as? String ?? doc.documentID
                return user
            }

            self.currentUser = allUsers.first(where: { $0.uid == uid })
            self.users = allUsers.filter { $0.uid != uid }
            
            print("📄 Loaded \(self.users.count) users (excluding current user)")
            print("👤 Current user: \(self.currentUser?.displayName ?? "Unknown")")
            
            // Load friend requests
            self.loadFriendRequests()
            
            self.loading = false
        }
    }
    
    private func loadFriendRequests() {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        print("🔄 Loading friend requests for user: \(currentUserId)")
        
        // Load incoming requests from subcollection
        db.collection("users").document(currentUserId)
            .collection("incomingFriendRequests")
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("❌ Error loading incoming requests: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents else { 
                    print("📄 No incoming requests found")
                    self.incomingRequests = []
                    return 
                }
                
                let requestIds = documents.map { $0.documentID }
                print("📄 Found \(requestIds.count) incoming requests: \(requestIds)")
                
                self.incomingRequests = self.users.filter { requestIds.contains($0.uid) }
                print("✅ Loaded \(self.incomingRequests.count) incoming request profiles")
            }
        
        // Load outgoing requests from subcollection
        db.collection("users").document(currentUserId)
            .collection("outgoingFriendRequests")
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("❌ Error loading outgoing requests: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents else { 
                    print("📄 No outgoing requests found")
                    self.outgoingRequests = []
                    return 
                }
                
                let requestIds = documents.map { $0.documentID }
                print("📄 Found \(requestIds.count) outgoing requests: \(requestIds)")
                
                self.outgoingRequests = self.users.filter { requestIds.contains($0.uid) }
                print("✅ Loaded \(self.outgoingRequests.count) outgoing request profiles")
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
                    print("✅ Friend request sent successfully!")
                    // Reload data to update the UI immediately
                    self.reloadData()
                } else {
                    print("❌ Friend request failed")
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
        let inviteText = "🍵 Check out Chai Finder! Download it and add me as a friend."
        let av = UIActivityViewController(activityItems: [inviteText], applicationActivities: nil)

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(av, animated: true)
        }
    }
} 