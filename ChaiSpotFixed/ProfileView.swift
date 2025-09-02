import SwiftUI
import FirebaseFirestore // Added for Firestore

struct ProfileView: View {
    @EnvironmentObject var sessionStore: SessionStore
    @EnvironmentObject var weeklyRankingService: WeeklyRankingService
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
    @State private var showingPrivacySettings = false
    @State private var showingChaiJourney = false
    @State private var showingWeeklyChallenge = false
    @State private var showingLeaderboard = false
    @State private var showingScoreDetails = false
    @State private var showingStreak = false
    @State private var showingBadgeCollection = false
    @State private var showingEditPhoto = false
    @State private var showingNotificationSettings = false
    @State private var showingTopSpots = false
    @State private var isRefreshing = false
    @State private var hasAcceptedTerms = false
    @State private var profileRefreshTrigger = UUID()
    
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

                    // 🏆 Achievements Preview - Moved to Social View as Leaderboard

                    // Weekly Challenge section removed (already available in Social)

                    // 📍 Saved Spots
                    savedSpotsSection
                    
                    // ⭐ Top Spots
                    topSpotsSection
                    
                    // 🔒 Privacy & Settings
                    privacySettingsSection
                    
                    // ⚙️ Settings
                    settingsSection
                }
                .padding(.bottom, DesignSystem.Spacing.xl)
                .id(profileRefreshTrigger) // Force refresh when profile changes
                .onAppear {
                    print("🔄 ProfileView body appeared with profileRefreshTrigger: \(profileRefreshTrigger)")
                }
            }
            .background(DesignSystem.Colors.background)
            .refreshable {
                await refreshProfile()
            }
            .navigationBarHidden(true)

            .onChange(of: sessionStore.userProfile?.photoURL) { newPhotoURL in
                profileRefreshTrigger = UUID()
            }
            .onReceive(sessionStore.objectWillChange) {
                profileRefreshTrigger = UUID()
            }
            .onAppear {
                // Recalculate total score when profile appears
                Task {
                    await gamificationService.updateTotalScore()
                }
            }
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
        .sheet(isPresented: $showingEditPhoto) {
            EditProfilePhotoView()
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
        .sheet(isPresented: $showingScoreDetails) {
            ScoreDetailsView(gamificationService: gamificationService)
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
        .sheet(isPresented: $showingTopSpots) {
            UserTopSpotsView()
                .environmentObject(sessionStore)
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
        .onReceive(NotificationCenter.default.publisher(for: .savedSpotsChanged)) { _ in
            loadSavedSpotsCount()
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: DesignSystem.Spacing.sm) { // Reduced spacing for more compact design
            HStack {
                // Brand title - consistent with other pages
                Text("chai finder")
                    .font(DesignSystem.Typography.titleLarge)
                    .fontWeight(.bold)
                    .foregroundColor(DesignSystem.Colors.primary)
                    .accessibilityLabel("App title: chai finder")
                
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
                        .frame(width: 32, height: 32)
                        .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                        .animation(isRefreshing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isRefreshing)
                }
                .frame(width: 32, height: 32)
                .background(DesignSystem.Colors.primary.opacity(0.1))
                .cornerRadius(DesignSystem.CornerRadius.small)
                .disabled(isRefreshing)
                .accessibilityLabel("Refresh profile")
                .accessibilityHint("Double tap to refresh profile data")
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .background(DesignSystem.Colors.background)
        .iPadOptimized()
    }
    
    // MARK: - Profile Header Section
    private var profileHeaderSection: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            // Profile Image with Streak Badge
            Button(action: {
                showingEditPhoto = true
            }) {
                ZStack {
                    // Display user's photo if available, otherwise show default icon
                    if let photoURL = sessionStore.userProfile?.photoURL,
                       !photoURL.isEmpty {
                        Group {
                            // Check if this is a base64 data URL
                            if photoURL.hasPrefix("data:image") {
                                // Handle base64 data URL
                                if let data = Data(base64Encoded: photoURL.replacingOccurrences(of: "data:image/jpeg;base64,", with: "")),
                                   let uiImage = UIImage(data: data) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        
                                } else {
                                    // Fallback if base64 decoding fails
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.red)
                                        .onAppear {
                                            print("❌ Failed to decode base64 profile photo")
                                            print("❌ PhotoURL: \(photoURL)")
                                            print("❌ PhotoURL length: \(photoURL.count)")
                                            let base64Part = photoURL.replacingOccurrences(of: "data:image/jpeg;base64,", with: "")
                                            print("❌ Base64 part length: \(base64Part.count)")
                                        }
                                }
                            } else {
                                // Handle regular URL
                                AsyncImage(url: URL(string: photoURL)) { phase in
                                    switch phase {
                                    case .empty:
                                        ProgressView()
                                            .scaleEffect(1.5)
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                    case .failure(let error):
                                        VStack {
                                            Image(systemName: "exclamationmark.triangle.fill")
                                                .foregroundColor(.red)
                                            Text("Failed to load")
                                                .font(.caption)
                                                .foregroundColor(.red)
                                        }
                                        .onAppear {
                                            print("❌ AsyncImage failed to load photo: \(error.localizedDescription)")
                                            print("🔍 Failed URL: \(photoURL)")
                                        }
                                    @unknown default:
                                        ProgressView()
                                            .scaleEffect(1.5)
                                    }
                                }

                            }
                        }
                        .frame(width: UIDevice.current.userInterfaceIdiom == .pad ? 120 : 80, 
                               height: UIDevice.current.userInterfaceIdiom == .pad ? 120 : 80)
                        .clipShape(Circle())
                    } else {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: UIDevice.current.userInterfaceIdiom == .pad ? 120 : 80))
                            .foregroundColor(DesignSystem.Colors.primary)
                            .onAppear {
                                print("🔍 Showing default profile icon - photoURL: \(sessionStore.userProfile?.photoURL ?? "nil")")
                            }
                    }
                    
                    // Celebratory Streak Banner (top left of profile picture, rotated -90 degrees)
                    HStack {
                        // Streak Banner
                        VStack {
                            HStack {
                                ZStack {
                                    // Celebratory background with gradient and sparkles
                                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                                        .fill(
                                            LinearGradient(
                                                gradient: Gradient(colors: [
                                                    DesignSystem.Colors.accent,
                                                    DesignSystem.Colors.accent.opacity(0.8),
                                                    DesignSystem.Colors.accent
                                                ]),
                                                startPoint: .bottomLeading,
                                                endPoint: .topTrailing
                                            )
                                        )
                                        .frame(width: UIDevice.current.userInterfaceIdiom == .pad ? 140 : 120, 
                                               height: UIDevice.current.userInterfaceIdiom == .pad ? 50 : 40)
                                        .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
                                        .overlay(
                                            // Sparkle effect
                                            ZStack {
                                                ForEach(0..<3) { index in
                                                    Image(systemName: "sparkle")
                                                        .foregroundColor(.white.opacity(0.6))
                                                        .font(.system(size: 8))
                                                        .offset(
                                                            x: CGFloat(index * 15 - 15),
                                                            y: CGFloat(index * 8 - 8)
                                                        )
                                                }
                                            }
                                        )
                                    
                                    // Streak text with celebration - positioned to start from bottom-left
                                    VStack(spacing: 2) {
                                        Text("\(gamificationService.currentStreak)")
                                            .font(.system(size: UIDevice.current.userInterfaceIdiom == .pad ? 18 : 16, weight: .bold))
                                            .foregroundColor(.white)
                                        
                                        Text("WEEK STREAK!")
                                            .font(.system(size: UIDevice.current.userInterfaceIdiom == .pad ? 10 : 8, weight: .bold))
                                            .foregroundColor(.white)
                                            .minimumScaleFactor(0.7)
                                    }
                                    .offset(x: UIDevice.current.userInterfaceIdiom == .pad ? -10 : -8, 
                                           y: UIDevice.current.userInterfaceIdiom == .pad ? 8 : 6)
                                }
                                .rotationEffect(.degrees(-45))
                                .offset(x: UIDevice.current.userInterfaceIdiom == .pad ? -25 : -20, 
                                       y: UIDevice.current.userInterfaceIdiom == .pad ? -25 : -20)
                                Spacer()
                            }
                            Spacer()
                        }
                        Spacer()
                    }
                    .onAppear {
                        print("🔍 Streak banner appeared - currentStreak: \(gamificationService.currentStreak)")
                    }
                    
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
                
                // Photo status indicator
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: sessionStore.userProfile?.photoURL?.isEmpty == false ? "checkmark.circle.fill" : "exclamationmark.circle")
                        .font(.caption)
                        .foregroundColor(sessionStore.userProfile?.photoURL?.isEmpty == false ? DesignSystem.Colors.success : DesignSystem.Colors.warning)
                    
                    Text(sessionStore.userProfile?.photoURL?.isEmpty == false ? "Profile photo set" : "Add a profile photo")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(sessionStore.userProfile?.photoURL?.isEmpty == false ? DesignSystem.Colors.success : DesignSystem.Colors.warning)
                }
                .padding(.horizontal, DesignSystem.Spacing.sm)
                .padding(.vertical, DesignSystem.Spacing.xs)
                .background((sessionStore.userProfile?.photoURL?.isEmpty == false ? DesignSystem.Colors.success : DesignSystem.Colors.warning).opacity(0.1))
                .cornerRadius(DesignSystem.CornerRadius.small)
            }
            

        }
        .padding(.top, DesignSystem.Spacing.lg)
        .iPadCardStyle()
    }
    
    // MARK: - Stats Section
    private var statsSection: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Button(action: {
                showingScoreDetails = true
            }) {
                StatCard(
                    title: "Score",
                    value: "\(gamificationService.totalScore)",
                    icon: "star.fill",
                    color: DesignSystem.Colors.primary
                )
            }
            .buttonStyle(PlainButtonStyle())
            .contextMenu {
                Button("Recalculate Score") {
                    Task {
                        await gamificationService.updateTotalScore()
                    }
                }
                .disabled(isRefreshing)
            }
            
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
                showingFriends = true
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
                Text("🔥 Weekly Streak")
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
    
    // MARK: - Top Spots Section
    private var topSpotsSection: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            HStack {
                Text("⭐ Top Spots")
                    .font(DesignSystem.Typography.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("View All") {
                    showingTopSpots = true
                }
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.primary)
                .accessibilityLabel("View all top spots")
            }
            
            Button(action: {
                showingTopSpots = true
            }) {
                HStack {
                    Image(systemName: "star.circle.fill")
                        .foregroundColor(DesignSystem.Colors.ratingGreen)
                        .accessibilityHidden(true)
                    
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text("Your 5-Star Favorites")
                            .font(DesignSystem.Typography.bodyMedium)
                            .fontWeight(.medium)
                        
                        Text("See how the community rates your top picks")
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
            .accessibilityLabel("View top spots")
            .accessibilityHint("Double tap to view your 5-star rated spots ranked by community score")
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
                    icon: "trophy",
                    title: "Test Weekly Ranking",
                    action: {
                        Task {
                            await weeklyRankingService.triggerWeeklyRankingNotification()
                        }
                    }
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
        loadSavedSpotsCount()
    }
    
    private func loadSavedSpotsCount() {
        guard let userId = sessionStore.userProfile?.uid else { return }
        
        let db = Firestore.firestore()
        db.collection("users").document(userId).getDocument { snapshot, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Failed to load saved spots count: \(error.localizedDescription)")
                    self.savedSpotsCount = 0
                    return
                }
                
                guard let data = snapshot?.data(),
                      let savedSpotIds = data["savedSpots"] as? [String] else {
                    self.savedSpotsCount = 0
                    return
                }
                
                self.savedSpotsCount = savedSpotIds.count
            }
        }
    }
    
    private func refreshProfile() async {
        isRefreshing = true
        
        // Refresh gamification data and recalculate scores
        gamificationService.refreshData()
        await gamificationService.updateTotalScore()
        
        // Simulate refresh
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        await MainActor.run {
            isRefreshing = false
            loadProfileData()
            loadSavedSpotsCount() // Reload saved spots count on refresh
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
