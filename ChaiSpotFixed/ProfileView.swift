import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var sessionStore: SessionStore
    @State private var showingEditBio = false
    @State private var showingEditName = false
    @State private var showingDeleteAccount = false
    @State private var savedSpotsCount = 0
    @State private var showingSavedSpots = false
    @State private var showingFriends = false
    @State private var showingBlockedUsers = false
    @State private var showingTermsOfService = false

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
                            HStack {
                                Text(sessionStore.userProfile?.displayName ?? "User")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                
                                Button(action: {
                                    showingEditName = true
                                }) {
                                    Image(systemName: "pencil")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                            }

                            Text(sessionStore.userProfile?.email ?? "")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.top, 20)

                    // Stats
                    HStack(spacing: 40) {
                        Button(action: {
                            showingSavedSpots = true
                        }) {
                            VStack {
                                Text("\(savedSpotsCount)")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                Text("Saved Spots")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color(.systemGray4), lineWidth: 1)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())

                        Button(action: {
                            showingFriends = true
                        }) {
                            VStack {
                                Text("\(sessionStore.userProfile?.friends?.count ?? 0)")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                Text("Friends")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color(.systemGray4), lineWidth: 1)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
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

                    // Safety & Privacy Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Safety & Privacy")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        VStack(spacing: 8) {
                            Button(action: {
                                showingBlockedUsers = true
                            }) {
                                HStack {
                                    Image(systemName: "person.slash")
                                        .foregroundColor(.red)
                                    Text("Blocked Users")
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.secondary)
                                        .font(.caption)
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Button(action: {
                                showingTermsOfService = true
                            }) {
                                HStack {
                                    Image(systemName: "doc.text")
                                        .foregroundColor(.blue)
                                    Text("Terms of Service")
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.secondary)
                                        .font(.caption)
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(.horizontal)
                    }

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
            .sheet(isPresented: $showingEditName) {
                EditNameView()
                    .environmentObject(sessionStore)
            }
            .sheet(isPresented: $showingSavedSpots) {
                SavedSpotsView()
            }
            .sheet(isPresented: $showingFriends) {
                FriendsListView()
            }
            .sheet(isPresented: $showingBlockedUsers) {
                UserBlockingView()
            }
            .sheet(isPresented: $showingTermsOfService) {
                TermsOfServiceView(hasAcceptedTerms: .constant(true), isReadOnly: true)
            }
            .alert("Delete Account", isPresented: $showingDeleteAccount) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    sessionStore.signOut()
                }
            } message: {
                Text("Are you sure you want to delete your account? This action cannot be undone.")
            }
            .onAppear {
                loadSavedSpotsCount()
            }
        }
    }
    
    private func loadSavedSpotsCount() {
        Task {
            let count = await sessionStore.loadSavedSpotsCount()
            DispatchQueue.main.async {
                self.savedSpotsCount = count
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
