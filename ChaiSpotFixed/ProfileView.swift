import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var sessionStore: SessionStore
    @State private var showingEditBio = false
    @State private var showingDeleteAccount = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Profile Header
                    VStack(spacing: 16) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.orange)

                        VStack(spacing: 8) {
                            Text(sessionStore.userProfile?.displayName ?? "User")
                                .font(.title2)
                                .fontWeight(.semibold)

                            Text(sessionStore.userProfile?.email ?? "")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.top, 20)

                    // Stats
                    HStack(spacing: 40) {
                        VStack {
                            Text("0")
                                .font(.title2)
                                .fontWeight(.bold)
                            Text("Saved Spots")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        VStack {
                            Text("\(sessionStore.userProfile?.friends?.count ?? 0)")
                                .font(.title2)
                                .fontWeight(.bold)
                            Text("Friends")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 20)

                    // Bio Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Bio")
                                .font(.headline)
                            Spacer()
                            Button("Edit") {
                                showingEditBio = true
                            }
                            .foregroundColor(.orange)
                        }

                        Text(sessionStore.userProfile?.bio ?? "No bio yet")
                            .foregroundColor(.secondary)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                    .padding(.horizontal)

                    // Actions
                    VStack(spacing: 12) {
                        Button("Sign Out") {
                            sessionStore.signOut()
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(10)

                        Button("Delete Account") {
                            showingDeleteAccount = true
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray5))
                        .foregroundColor(.red)
                        .cornerRadius(10)
                    }
                    .padding(.horizontal)

                    Spacer()
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingEditBio) {
                EditBioView()
                    .environmentObject(sessionStore)
            }
            .alert("Delete Account", isPresented: $showingDeleteAccount) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    sessionStore.signOut()
                }
            } message: {
                Text("Are you sure you want to delete your account? This action cannot be undone.")
            }
        }
    }
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
            .environmentObject(SessionStore())
    }
}
