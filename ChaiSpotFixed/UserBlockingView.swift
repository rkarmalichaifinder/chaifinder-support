import SwiftUI
import FirebaseFirestore

struct UserBlockingView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var moderationService = ContentModerationService()
    @State private var blockedUsers: [BlockedUser] = []
    @State private var isLoading = true
    
    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView("Loading blocked users...")
                } else if blockedUsers.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "person.slash")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        
                        Text("No Blocked Users")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Users you block will appear here. You can unblock them at any time.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                } else {
                    List(blockedUsers) { blockedUser in
                        BlockedUserRow(blockedUser: blockedUser) {
                            unblockUser(blockedUser)
                        }
                    }
                }
            }
            .navigationTitle("Blocked Users")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            loadBlockedUsers()
        }
    }
    
    private func loadBlockedUsers() {
        moderationService.getBlockedUsers { blockedUserIds in
            // Fetch user details for blocked users
            let db = Firestore.firestore()
            let group = DispatchGroup()
            var users: [BlockedUser] = []
            
            for userId in blockedUserIds {
                group.enter()
                db.collection("users").document(userId).getDocument { snapshot, error in
                    defer { group.leave() }
                    
                    if let data = snapshot?.data() {
                        let displayName = data["displayName"] as? String ?? "Unknown User"
                        let email = data["email"] as? String ?? ""
                        users.append(BlockedUser(id: userId, displayName: displayName, email: email))
                    } else {
                        users.append(BlockedUser(id: userId, displayName: "Unknown User", email: ""))
                    }
                }
            }
            
            group.notify(queue: .main) {
                self.blockedUsers = users.sorted { $0.displayName < $1.displayName }
                self.isLoading = false
            }
        }
    }
    
    private func unblockUser(_ blockedUser: BlockedUser) {
        moderationService.unblockUser(userIdToUnblock: blockedUser.id)
        
        // Remove from local array
        blockedUsers.removeAll { $0.id == blockedUser.id }
    }
}

struct BlockedUserRow: View {
    let blockedUser: BlockedUser
    let onUnblock: () -> Void
    
    @State private var showingUnblockAlert = false
    
    var body: some View {
        HStack {
            Circle()
                .fill(Color(.systemGray4))
                .frame(width: 40, height: 40)
                .overlay(
                    Text(String(blockedUser.displayName.prefix(1)).uppercased())
                        .font(.headline)
                        .foregroundColor(.secondary)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(blockedUser.displayName)
                    .font(.body)
                    .fontWeight(.medium)
                
                if !blockedUser.email.isEmpty {
                    Text(blockedUser.email)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button("Unblock") {
                showingUnblockAlert = true
            }
            .foregroundColor(.blue)
        }
        .alert("Unblock User", isPresented: $showingUnblockAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Unblock", role: .destructive) {
                onUnblock()
            }
        } message: {
            Text("Are you sure you want to unblock \(blockedUser.displayName)? You will be able to see their content again.")
        }
    }
}

struct BlockedUser: Identifiable {
    let id: String
    let displayName: String
    let email: String
} 