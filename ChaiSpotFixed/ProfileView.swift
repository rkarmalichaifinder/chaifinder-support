import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var sessionStore: SessionStore
    @StateObject private var gamificationService = GamificationService()
    @State private var showingEditBio = false
    @State private var showingEditName = false
    @State private var showingDeleteAccount = false
    @State private var savedSpotsCount = 0
    @State private var showingSavedSpots = false
    @State private var showingFriends = false
    @State private var showingBlockedUsers = false
    @State private var showingTermsOfService = false
    @State private var showingBadges = false
    @State private var showingAchievements = false
    @State private var showingNotificationSettings = false
    @State private var showingPrivacySettings = false
    @State private var showingWeeklyChallenge = false
    @State private var isRefreshing = false
    @State private var hasAcceptedTerms = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.lg) {
                    // Header
                    headerSection
                    
                    // Profile Header
                    profileHeaderSection
                    
                    // Stats Section
                    statsSection
                    
                    // 🔥 Streak Section
                    if gamificationService.currentStreak > 0 || gamificationService.longestStreak > 0 {
                        streakSection
                    }

                    // 🎖️ Badges Preview
                    if !gamificationService.userBadges.isEmpty {
                        badgesSection
                    }

                    // 🏆 Achievements Preview
                    if !gamificationService.userAchievements.isEmpty {
                        achievementsSection
                    }

                    // 🎯 Weekly Challenge
                    weeklyChallengeSection

                    // 📍 Saved Spots
                    savedSpotsSection
                    
                    // 🔒 Privacy & Settings
                    privacySettingsSection
                    
                    // 👥 Friends
                    friendsSection
                    
                    // ⚙️ Settings
                    settingsSection
                }
                .padding(.bottom, DesignSystem.Spacing.xl)
            }
            .background(DesignSystem.Colors.background)
            .refreshable {
                await refreshProfile()
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(.stack)
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
                .environmentObject(sessionStore)
        }
        .sheet(isPresented: $showingFriends) {
            FriendsListView()
                .environmentObject(sessionStore)
        }
        .sheet(isPresented: $showingBadges) {
            BadgeCollectionView(gamificationService: gamificationService)
                .environmentObject(sessionStore)
        }
        .sheet(isPresented: $showingAchievements) {
            LeaderboardView()
                .environmentObject(sessionStore)
        }
        .sheet(isPresented: $showingWeeklyChallenge) {
            WeeklyChallengeView()
        }
        .sheet(isPresented: $showingBlockedUsers) {
            UserBlockingView()
                .environmentObject(sessionStore)
        }
        .sheet(isPresented: $showingTermsOfService) {
            TermsOfServiceView(hasAcceptedTerms: $hasAcceptedTerms)
        }
        .sheet(isPresented: $showingNotificationSettings) {
            NotificationSettingsView()
        }
        .sheet(isPresented: $showingPrivacySettings) {
            PrivacySettingsView()
        }
        .alert("Delete Account", isPresented: $showingDeleteAccount) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                // Handle account deletion
            }
        } message: {
            Text("This action cannot be undone. All your data will be permanently deleted.")
        }
        .onAppear {
            loadProfileData()
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            HStack {
                Text("Profile")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .accessibilityLabel("Current page: Profile")
                
                Spacer()
                
                // Refresh button
                Button(action: {
                    Task {
                        await refreshProfile()
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(DesignSystem.Colors.primary)
                        .font(.system(size: 16))
                        .frame(width: 44, height: 44)
                        .background(DesignSystem.Colors.primary.opacity(0.1))
                        .cornerRadius(DesignSystem.CornerRadius.medium)
                        .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                        .animation(isRefreshing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isRefreshing)
                }
                .disabled(isRefreshing)
                .accessibilityLabel("Refresh profile")
                .accessibilityHint("Double tap to refresh profile data")
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text("chai finder")
                .font(DesignSystem.Typography.titleLarge)
                .fontWeight(.bold)
                .foregroundColor(DesignSystem.Colors.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityLabel("App title: chai finder")
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.background)
        .iPadOptimized()
    }
    
    // MARK: - Profile Header Section
    private var profileHeaderSection: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            // Profile Image
            Button(action: {
                // TODO: Add profile image editing
            }) {
                ZStack {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: UIDevice.current.userInterfaceIdiom == .pad ? 120 : 80))
                        .foregroundColor(DesignSystem.Colors.primary)
                        .accessibilityHidden(true)
                    
                    // Edit indicator
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Image(systemName: "pencil.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                                .background(DesignSystem.Colors.primary)
                                .clipShape(Circle())
                        }
                    }
                }
            }
            .accessibilityLabel("Profile picture")
            .accessibilityHint("Double tap to edit profile picture")

            // Name and Email
            VStack(spacing: DesignSystem.Spacing.sm) {
                HStack {
                    Text(sessionStore.userProfile?.displayName ?? "User")
                        .font(DesignSystem.Typography.headline)
                        .fontWeight(.semibold)
                        .accessibilityLabel("User name: \(sessionStore.userProfile?.displayName ?? "User")")
                    
                    Button(action: {
                        showingEditName = true
                    }) {
                        Image(systemName: "pencil")
                            .font(.caption)
                            .foregroundColor(DesignSystem.Colors.primary)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Edit name")
                    .accessibilityHint("Double tap to edit your name")
                }

                Text(sessionStore.userProfile?.email ?? "")
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .accessibilityLabel("Email address")
            }
            

        }
        .padding(.top, DesignSystem.Spacing.lg)
        .iPadCardStyle()
    }
    
    // MARK: - Stats Section
    private var statsSection: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Button(action: {
                // TODO: Navigate to detailed score view
                print("Score tapped: \(gamificationService.totalScore)")
            }) {
                StatCard(
                    title: "Score",
                    value: "\(gamificationService.totalScore)",
                    icon: "star.fill",
                    color: DesignSystem.Colors.primary
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            Button(action: {
                showingBadges = true
            }) {
                StatCard(
                    title: "Badges",
                    value: "\(gamificationService.userBadges.count)",
                    icon: "mappin.circle.fill",
                    color: DesignSystem.Colors.secondary
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            Button(action: {
                // TODO: Navigate to friends list view
                print("Friends tapped: \(sessionStore.userProfile?.friends?.count ?? 0)")
            }) {
                StatCard(
                    title: "Friends",
                    value: "\(sessionStore.userProfile?.friends?.count ?? 0)",
                    icon: "person.2.fill",
                    color: DesignSystem.Colors.info
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .iPadCardStyle()
    }
    
    // MARK: - Streak Section
    private var streakSection: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            HStack {
                Text("🔥 Current Streak")
                    .font(DesignSystem.Typography.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("View Details") {
                    // TODO: Navigate to detailed streak view
                }
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.primary)
                .accessibilityLabel("View streak details")
            }
            
            StreakView(
                currentStreak: gamificationService.currentStreak,
                longestStreak: gamificationService.longestStreak,
                lastReviewDate: sessionStore.userProfile?.lastReviewDate
            )
        }
        .iPadCardStyle()
    }
    
    // MARK: - Badges Section
    private var badgesSection: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            HStack {
                Text("🎖️ Recent Badges")
                    .font(DesignSystem.Typography.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("View All") {
                    showingBadges = true
                }
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.primary)
                .accessibilityLabel("View all badges")
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignSystem.Spacing.md) {
                    ForEach(Array(gamificationService.userBadges.prefix(5)), id: \.id) { badge in
                        BadgeView(badge: badge)
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.sm)
            }
        }
        .iPadCardStyle()
    }
    
    // MARK: - Achievements Section
    private var achievementsSection: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            HStack {
                Text("🏆 Achievements")
                    .font(DesignSystem.Typography.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("View All") {
                    showingAchievements = true
                }
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.primary)
                .accessibilityLabel("View all achievements")
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignSystem.Spacing.md) {
                    ForEach(Array(gamificationService.userAchievements.prefix(5)), id: \.id) { achievement in
                        AchievementView(achievement: achievement)
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.sm)
            }
        }
        .iPadCardStyle()
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
    
    // MARK: - Saved Spots Section
    private var savedSpotsSection: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            HStack {
                Text("📍 Saved Spots")
                    .font(DesignSystem.Typography.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("View All") {
                    showingSavedSpots = true
                }
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.primary)
                .accessibilityLabel("View all saved spots")
            }
            
            Button(action: {
                showingSavedSpots = true
            }) {
                HStack {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundColor(DesignSystem.Colors.primary)
                        .accessibilityHidden(true)
                    
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text("\(savedSpotsCount) spots saved")
                            .font(DesignSystem.Typography.bodyMedium)
                            .fontWeight(.medium)
                        
                        Text("Tap to view your collection")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .accessibilityHidden(true)
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
            .accessibilityLabel("View saved spots")
            .accessibilityHint("Double tap to view your collection of saved chai spots")
        }
        .iPadCardStyle()
    }
    
    // MARK: - Privacy & Settings Section
    private var privacySettingsSection: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            HStack {
                Text("🔒 Privacy & Settings")
                    .font(DesignSystem.Typography.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            VStack(spacing: DesignSystem.Spacing.sm) {
                Button(action: {
                    showingPrivacySettings = true
                }) {
                    HStack {
                        Image(systemName: "lock.shield.fill")
                            .foregroundColor(DesignSystem.Colors.primary)
                            .accessibilityHidden(true)
                        
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                            Text("Privacy Settings")
                                .font(DesignSystem.Typography.bodyMedium)
                                .fontWeight(.medium)
                            
                            Text("Control your data and review visibility")
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .accessibilityHidden(true)
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
                .accessibilityLabel("Privacy settings")
                .accessibilityHint("Double tap to control your data privacy")
                
                Button(action: {
                    showingNotificationSettings = true
                }) {
                    HStack {
                        Image(systemName: "bell.fill")
                            .foregroundColor(DesignSystem.Colors.secondary)
                            .accessibilityHidden(true)
                        
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                            Text("Notification Settings")
                                .font(DesignSystem.Typography.bodyMedium)
                                .fontWeight(.medium)
                            
                            Text("Manage your notification preferences")
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .accessibilityHidden(true)
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
                .accessibilityLabel("Notification settings")
                .accessibilityHint("Double tap to manage notifications")
            }
        }
        .iPadCardStyle()
    }
    
    // MARK: - Friends Section
    private var friendsSection: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            HStack {
                Text("👥 Friends")
                    .font(DesignSystem.Typography.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("View All") {
                    showingFriends = true
                }
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.primary)
                .accessibilityLabel("View all friends")
            }
            
            Button(action: {
                showingFriends = true
            }) {
                HStack {
                    Image(systemName: "person.3.fill")
                        .foregroundColor(DesignSystem.Colors.primary)
                        .accessibilityHidden(true)
                    
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text("\(sessionStore.userProfile?.friends?.count ?? 0) friends")
                            .font(DesignSystem.Typography.bodyMedium)
                            .fontWeight(.medium)
                        
                        Text("Tap to manage your connections")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .accessibilityHidden(true)
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
            .accessibilityLabel("View friends")
            .accessibilityHint("Double tap to manage your friend connections")
        }
        .iPadCardStyle()
    }
    
    // MARK: - Settings Section
    private var settingsSection: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Text("⚙️ Settings")
                .font(DesignSystem.Typography.headline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: DesignSystem.Spacing.xs) {
                SettingsRow(
                    icon: "person.crop.circle",
                    title: "Edit Profile",
                    action: { showingEditBio = true }
                )
                
                SettingsRow(
                    icon: "bell",
                    title: "Notifications",
                    action: { showingNotificationSettings = true }
                )
                
                SettingsRow(
                    icon: "person.2.slash",
                    title: "Blocked Users",
                    action: { showingBlockedUsers = true }
                )
                
                SettingsRow(
                    icon: "doc.text",
                    title: "Terms of Service",
                    action: { showingTermsOfService = true }
                )
                
                SettingsRow(
                    icon: "trash",
                    title: "Delete Account",
                    action: { showingDeleteAccount = true },
                    isDestructive: true
                )
                
                SettingsRow(
                    icon: "rectangle.portrait.and.arrow.right",
                    title: "Sign Out",
                    action: {
                        sessionStore.signOut()
                    },
                    isDestructive: true
                )
            }
        }
        .iPadCardStyle()
    }
    
    // MARK: - Helper Functions
    private func loadProfileData() {
        // Load profile data - placeholder for now
        savedSpotsCount = 0 // TODO: Implement actual saved spots count
    }
    
    private func refreshProfile() async {
        isRefreshing = true
        
        // Simulate refresh
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        await MainActor.run {
            isRefreshing = false
            loadProfileData()
        }
    }
}

// MARK: - Supporting Views
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
                .accessibilityHidden(true)
            
            Text(value)
                .font(DesignSystem.Typography.titleMedium)
                .fontWeight(.bold)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            
            Text(title)
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                .stroke(DesignSystem.Colors.border, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }
}

struct SettingsRow: View {
    let icon: String
    let title: String
    let action: () -> Void
    let isDestructive: Bool
    
    init(icon: String, title: String, action: @escaping () -> Void, isDestructive: Bool = false) {
        self.icon = icon
        self.title = title
        self.action = action
        self.isDestructive = isDestructive
    }
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(isDestructive ? DesignSystem.Colors.error : DesignSystem.Colors.primary)
                    .frame(width: 24)
                    .accessibilityHidden(true)
                
                Text(title)
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(isDestructive ? DesignSystem.Colors.error : DesignSystem.Colors.textPrimary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .font(.caption)
                    .accessibilityHidden(true)
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
        .frame(minHeight: DesignSystem.Layout.minTouchTarget)
        .accessibilityLabel(title)
        .accessibilityHint("Double tap to \(title.lowercased())")
    }
}

// MARK: - Preview
struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
            .environmentObject(SessionStore())
    }
}
