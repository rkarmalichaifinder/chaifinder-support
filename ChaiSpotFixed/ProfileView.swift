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
                VStack(spacing: DesignSystem.Spacing.lg) {
                    // Profile Header
                    VStack(spacing: DesignSystem.Spacing.md) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: UIDevice.current.userInterfaceIdiom == .pad ? 120 : 80))
                            .foregroundColor(.orange)

                        VStack(spacing: DesignSystem.Spacing.sm) {
                            HStack {
                                Text(sessionStore.userProfile?.displayName ?? "User")
                                    .font(DesignSystem.Typography.headline)
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
                                .font(DesignSystem.Typography.bodyMedium)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.top, DesignSystem.Spacing.lg)
                    .iPadCardStyle()

                    // Stats
                    HStack(spacing: DesignSystem.Spacing.xl) {
                        Button(action: {
                            showingSavedSpots = true
                        }) {
                            VStack(spacing: DesignSystem.Spacing.sm) {
                                Text("\(savedSpotsCount)")
                                    .font(DesignSystem.Typography.headline)
                                    .fontWeight(.bold)
                                Text("Saved Spots")
                                    .font(DesignSystem.Typography.bodySmall)
                                    .foregroundColor(.secondary)
                            }
                            .padding(DesignSystem.Spacing.lg)
                            .frame(maxWidth: .infinity)
                            .background(Color(.systemGray6))
                            .cornerRadius(DesignSystem.CornerRadius.medium)
                            .overlay(
                                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                                    .stroke(Color(.systemGray4), lineWidth: 1)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())

                        Button(action: {
                            showingFriends = true
                        }) {
                            VStack(spacing: DesignSystem.Spacing.sm) {
                                Text("\(sessionStore.userProfile?.friends?.count ?? 0)")
                                    .font(DesignSystem.Typography.headline)
                                    .fontWeight(.bold)
                                Text("Friends")
                                    .font(DesignSystem.Typography.bodySmall)
                                    .foregroundColor(.secondary)
                            }
                            .padding(DesignSystem.Spacing.lg)
                            .frame(maxWidth: .infinity)
                            .background(Color(.systemGray6))
                            .cornerRadius(DesignSystem.CornerRadius.medium)
                            .overlay(
                                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                                    .stroke(Color(.systemGray4), lineWidth: 1)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.vertical, DesignSystem.Spacing.lg)

                    // Bio Section
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                        HStack {
                            Text("Bio")
                                .font(DesignSystem.Typography.headline)
                            Spacer()
                            Button("Edit") {
                                showingEditBio = true
                            }
                            .foregroundColor(.orange)
                        }

                        Text(sessionStore.userProfile?.bio ?? "No bio yet")
                            .foregroundColor(.secondary)
                            .padding(DesignSystem.Spacing.lg)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6))
                            .cornerRadius(DesignSystem.CornerRadius.medium)
                    }
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .iPadCardStyle()

                    // Safety & Privacy Section
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                        Text("Safety & Privacy")
                            .font(DesignSystem.Typography.headline)
                            .padding(.horizontal, DesignSystem.Spacing.lg)
                        
                        VStack(spacing: DesignSystem.Spacing.sm) {
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
                                .padding(DesignSystem.Spacing.lg)
                                .background(Color(.systemGray6))
                                .cornerRadius(DesignSystem.CornerRadius.medium)
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
                                .padding(DesignSystem.Spacing.lg)
                                .background(Color(.systemGray6))
                                .cornerRadius(DesignSystem.CornerRadius.medium)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .iPadCardStyle()

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
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) {
                        Image("AppLogo")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 24)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        Text("Profile")
                            .font(DesignSystem.Typography.titleMedium)
                            .fontWeight(.bold)
                    }
                }
            }
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
        .navigationViewStyle(.stack)
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
