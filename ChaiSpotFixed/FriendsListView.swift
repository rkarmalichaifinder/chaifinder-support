import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct FriendsListView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var friends: [UserProfile] = []
    @State private var loading = true
    @State private var errorMessage: String?
    @State private var showingFriendDetails = false
    @State private var selectedFriend: UserProfile?
    
    private let db = Firestore.firestore()
    
    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.Colors.background
                    .ignoresSafeArea()
                
                if loading {
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
                } else if friends.isEmpty {
                    VStack(spacing: DesignSystem.Spacing.lg) {
                        Image(systemName: "person.2")
                            .font(.system(size: 48))
                            .foregroundColor(DesignSystem.Colors.secondary)
                        
                        Text("No Friends Yet")
                            .font(DesignSystem.Typography.headline)
                            .fontWeight(.bold)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        
                        Text("You haven't added any friends yet. Go to the Friends tab to discover and connect with other users!")
                            .font(DesignSystem.Typography.bodyMedium)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(DesignSystem.Spacing.xl)
                } else {
                    ScrollView {
                        LazyVStack(spacing: DesignSystem.Spacing.md) {
                            ForEach(friends) { friend in
                                Button(action: {
                                    selectedFriend = friend
                                    showingFriendDetails = true
                                }) {
                                    friendCard(friend)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(DesignSystem.Spacing.lg)
                    }
                }
            }
            .navigationTitle("Friends")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingFriendDetails) {
                if let selectedFriend = selectedFriend {
                    FriendDetailView(friend: selectedFriend)
                }
            }
        }
        .onAppear {
            loadFriends()
        }
    }
    
    private func friendCard(_ friend: UserProfile) -> some View {
        HStack {
            // Profile Image
            let initials = friend.displayName
                .split(separator: " ")
                .compactMap { $0.first }
                .prefix(2)
                .map { String($0) }
                .joined()
            
            Text(initials.uppercased())
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background(DesignSystem.Colors.primary)
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(friend.displayName)
                    .font(DesignSystem.Typography.bodyLarge)
                    .fontWeight(.semibold)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                
                Text(friend.email)
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
            
            Spacer()
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.medium)
        .shadow(
            color: DesignSystem.Shadows.small.color,
            radius: DesignSystem.Shadows.small.radius,
            x: DesignSystem.Shadows.small.x,
            y: DesignSystem.Shadows.small.y
        )
    }
    
    private func loadFriends() {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            errorMessage = "Not logged in"
            loading = false
            return
        }
        
        print("🔄 Loading friends for user: \(currentUserId)")
        
        // First, get the current user's friends list
        db.collection("users").document(currentUserId).getDocument { snapshot, error in
            if let error = error {
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                    self.loading = false
                }
                return
            }
            
            guard let data = snapshot?.data(),
                  let friendIds = data["friends"] as? [String] else {
                DispatchQueue.main.async {
                    self.friends = []
                    self.loading = false
                }
                return
            }
            
            if friendIds.isEmpty {
                DispatchQueue.main.async {
                    self.friends = []
                    self.loading = false
                }
                return
            }
            
            // Now get the friend profiles
            let group = DispatchGroup()
            var loadedFriends: [UserProfile] = []
            
            for friendId in friendIds {
                group.enter()
                db.collection("users").document(friendId).getDocument { snapshot, error in
                    defer { group.leave() }
                    
                    if let error = error {
                        print("❌ Error loading friend \(friendId): \(error.localizedDescription)")
                        return
                    }
                    
                    guard let data = snapshot?.data() else {
                        print("❌ No data found for friend \(friendId)")
                        return
                    }
                    
                    let friend = UserProfile(
                        id: snapshot?.documentID,
                        uid: data["uid"] as? String ?? friendId,
                        displayName: data["displayName"] as? String ?? "Unknown User",
                        email: data["email"] as? String ?? "unknown",
                        photoURL: data["photoURL"] as? String,
                        friends: data["friends"] as? [String] ?? [],
                        incomingRequests: data["incomingRequests"] as? [String] ?? [],
                        outgoingRequests: data["outgoingRequests"] as? [String] ?? [],
                        bio: data["bio"] as? String
                    )
                    
                    loadedFriends.append(friend)
                }
            }
            
            group.notify(queue: .main) {
                self.friends = loadedFriends.sorted { $0.displayName < $1.displayName }
                self.loading = false
                print("✅ Loaded \(self.friends.count) friends")
            }
        }
    }
} 