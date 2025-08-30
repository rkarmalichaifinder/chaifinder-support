import SwiftUI

struct ScoreDetailsView: View {
    let gamificationService: GamificationService
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.Colors.background
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.lg) {
                        // Header with total score
                        totalScoreHeader
                        
                        // Score summary
                        scoreSummarySection
                        
                        // Score breakdown
                        scoreBreakdownSection
                        
                        // Recent score history
                        recentScoreHistorySection
                        
                        // Score tips
                        scoreTipsSection
                    }
                    .padding(DesignSystem.Spacing.lg)
                }
            }
            .navigationTitle("Score Details")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(DesignSystem.Colors.primary)
                }
            }
        }
    }
    
    // MARK: - Total Score Header
    private var totalScoreHeader: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            // Large score display
            VStack(spacing: DesignSystem.Spacing.sm) {
                Text("\(gamificationService.totalScore)")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(DesignSystem.Colors.primary)
                
                Text("Total Points")
                    .font(DesignSystem.Typography.bodyLarge)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
            
            // Rank indicator (if available)
            if let rank = gamificationService.userRank {
                HStack {
                    Image(systemName: "trophy.fill")
                        .foregroundColor(.yellow)
                    Text("Rank #\(rank)")
                        .font(DesignSystem.Typography.bodyMedium)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                }
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.vertical, DesignSystem.Spacing.sm)
                .background(DesignSystem.Colors.cardBackground)
                .cornerRadius(DesignSystem.CornerRadius.medium)
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.medium)
    }
    
    // MARK: - Score Summary Section
    private var scoreSummarySection: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            VStack(spacing: DesignSystem.Spacing.sm) {
                Text("\(gamificationService.userAchievements.count)")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(DesignSystem.Colors.primary)
                
                Text("Achievements")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            
            VStack(spacing: DesignSystem.Spacing.sm) {
                Text("\(gamificationService.currentStreak)")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(DesignSystem.Colors.error)
                
                Text("Weekly Streak")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            
            VStack(spacing: DesignSystem.Spacing.sm) {
                Text("\(gamificationService.userBadges.count)")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(DesignSystem.Colors.secondary)
                
                Text("Badges")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.medium)
    }
    
    // MARK: - Score Breakdown Section
    private var scoreBreakdownSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Score Breakdown")
                .font(DesignSystem.Typography.headline)
                .fontWeight(.semibold)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            
            if gamificationService.estimatedBreakdown.isEmpty {
                Text("No score breakdown available yet")
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .italic()
            } else {
                VStack(spacing: DesignSystem.Spacing.sm) {
                    ForEach(gamificationService.estimatedBreakdown) { item in
                        ScoreBreakdownRow(
                            title: item.title,
                            points: item.points,
                            icon: item.icon,
                            color: item.color,
                            isAchievement: item.isAchievement
                        )
                    }
                }
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.medium)
    }
    
    // MARK: - Recent Score History Section
    private var recentScoreHistorySection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Recent Score History")
                .font(DesignSystem.Typography.headline)
                .fontWeight(.semibold)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            
            if gamificationService.recentScoreHistory.isEmpty {
                Text("No recent score activity")
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .italic()
            } else {
                VStack(spacing: DesignSystem.Spacing.sm) {
                    ForEach(Array(gamificationService.recentScoreHistory.prefix(5)), id: \.id) { entry in
                        ScoreHistoryRow(entry: entry)
                    }
                }
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.medium)
    }
    
    // MARK: - Score Tips Section
    private var scoreTipsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("💡 Score Tips")
                .font(DesignSystem.Typography.headline)
                .fontWeight(.semibold)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                ScoreTipRow(
                    tip: "Add photos to your reviews for +15 points",
                    icon: "camera.fill"
                )
                
                ScoreTipRow(
                    tip: "Write detailed comments for up to +20 points",
                    icon: "text.bubble.fill"
                )
                
                ScoreTipRow(
                    tip: "Rate creaminess and strength for +10 points",
                    icon: "slider.horizontal.3"
                )
                
                ScoreTipRow(
                    tip: "Review new spots for +15 points",
                    icon: "mappin.circle.fill"
                )
                
                ScoreTipRow(
                    tip: "Maintain weekly streaks for +5 points per week",
                    icon: "flame.fill"
                )
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.medium)
    }
}

// MARK: - Supporting Views

struct ScoreBreakdownRow: View {
    let title: String
    let points: Int
    let icon: String
    let color: Color
    let isAchievement: Bool
    
    var body: some View {
        HStack {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .frame(width: 24)
                
                if isAchievement {
                    Image(systemName: "trophy.fill")
                        .foregroundColor(.yellow)
                        .font(.caption)
                }
            }
            
            Text(title)
                .font(DesignSystem.Typography.bodyMedium)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            
            Spacer()
            
            Text("+\(points)")
                .font(DesignSystem.Typography.bodyMedium)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
        .padding(.vertical, DesignSystem.Spacing.xs)
    }
}

struct ScoreHistoryRow: View {
    let entry: ScoreHistoryEntry
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.description)
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                
                Text(entry.date, style: .relative)
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
            
            Spacer()
            
            Text("+\(entry.points)")
                .font(DesignSystem.Typography.bodyMedium)
                .fontWeight(.semibold)
                .foregroundColor(DesignSystem.Colors.primary)
        }
        .padding(.vertical, DesignSystem.Spacing.xs)
    }
}

struct ScoreTipRow: View {
    let tip: String
    let icon: String
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: icon)
                .foregroundColor(DesignSystem.Colors.primary)
                .frame(width: 20)
            
            Text(tip)
                .font(DesignSystem.Typography.bodyMedium)
                .foregroundColor(DesignSystem.Colors.textSecondary)
        }
    }
}

// MARK: - Supporting Models

struct ScoreHistoryEntry: Identifiable {
    let id = UUID()
    let description: String
    let points: Int
    let date: Date
}

// MARK: - GamificationService Extensions

extension GamificationService {
    // Score breakdown properties - these are calculated based on available data
    var baseRatingPoints: Int {
        // Estimate base points from total score and achievements
        let basePoints = userAchievements.filter { $0.id.contains("review") }.reduce(0) { $0 + $1.points }
        return min(basePoints, totalScore)
    }
    
    var photoBonusPoints: Int {
        // Estimate photo bonus points
        let photoAchievements = userAchievements.filter { $0.id.contains("photo") }
        return photoAchievements.reduce(0) { $0 + $1.points }
    }
    
    var commentBonusPoints: Int {
        // Estimate comment bonus points (detailed reviews)
        let detailedAchievements = userAchievements.filter { $0.id.contains("detailed") }
        return detailedAchievements.reduce(0) { $0 + $1.points }
    }
    
    var detailedRatingPoints: Int {
        // Estimate detailed rating bonus points
        let detailedAchievements = userAchievements.filter { $0.id.contains("detailed") }
        return detailedAchievements.reduce(0) { $0 + $1.points }
    }
    
    var firstReviewPoints: Int {
        // First review bonus
        let firstReviewAchievement = userAchievements.first { $0.id == "first_review" }
        return firstReviewAchievement?.points ?? 0
    }
    
    var newSpotPoints: Int {
        // New spot exploration bonuses
        let spotAchievements = userAchievements.filter { $0.id.contains("spots") }
        return spotAchievements.reduce(0) { $0 + $1.points }
    }
    
    var streakPoints: Int {
        // Streak bonuses
        let streakAchievements = userAchievements.filter { $0.id.contains("streak") }
        return streakAchievements.reduce(0) { $0 + $1.points }
    }
    
    var userRank: Int? {
        // For now, return nil until ranking system is implemented
        return nil
    }
    
    var recentScoreHistory: [ScoreHistoryEntry] {
        // Create sample history based on achievements
        var history: [ScoreHistoryEntry] = []
        
        for achievement in userAchievements.prefix(5) {
            let description = "Unlocked: \(achievement.name)"
            let entry = ScoreHistoryEntry(
                description: description,
                points: achievement.points,
                date: achievement.unlockedAt ?? Date()
            )
            history.append(entry)
        }
        
        return history
    }
    
    var estimatedBreakdown: [ScoreBreakdownItem] {
        var breakdown: [ScoreBreakdownItem] = []
        
        // Add actual achievements
        for achievement in userAchievements {
            breakdown.append(ScoreBreakdownItem(
                title: achievement.name,
                points: achievement.points,
                icon: getIconForAchievement(achievement.id),
                color: getColorForAchievement(achievement.id),
                isAchievement: true
            ))
        }
        
        // Add badge points
        let badgePoints = userBadges.count * 10
        if badgePoints > 0 {
            breakdown.append(ScoreBreakdownItem(
                title: "Badges (\(userBadges.count))",
                points: badgePoints,
                icon: "mappin.circle.fill",
                color: DesignSystem.Colors.secondary,
                isAchievement: false
            ))
        }
        
        // Add streak points
        let streakPoints = currentStreak * 5
        if streakPoints > 0 {
            breakdown.append(ScoreBreakdownItem(
                title: "Weekly Streak (\(currentStreak) weeks)",
                points: streakPoints,
                icon: "flame.fill",
                color: DesignSystem.Colors.error,
                isAchievement: false
            ))
        }
        
        // Add longest streak milestone bonus
        let milestoneBonus = getStreakMilestoneBonus(longestStreak)
        if milestoneBonus > 0 {
            breakdown.append(ScoreBreakdownItem(
                title: "Longest Streak Milestone",
                points: milestoneBonus,
                icon: "trophy.fill",
                color: .yellow,
                isAchievement: false
            ))
        }
        
        // Add any remaining points from other activities
        let calculatedPoints = userAchievements.reduce(0) { $0 + $1.points } + badgePoints + streakPoints + milestoneBonus
        let remainingPoints = totalScore - calculatedPoints
        
        if remainingPoints > 0 {
            breakdown.append(ScoreBreakdownItem(
                title: "Other Activities",
                points: remainingPoints,
                icon: "plus.circle.fill",
                color: DesignSystem.Colors.primary,
                isAchievement: false
            ))
        }
        
        return breakdown
    }
    
    private func getStreakMilestoneBonus(_ streak: Int) -> Int {
        if streak >= 52 { return 100 }      // 1 year
        else if streak >= 26 { return 75 }  // 6 months
        else if streak >= 12 { return 50 }  // 3 months
        else if streak >= 8 { return 25 }   // 2 months
        else if streak >= 4 { return 15 }   // 1 month
        else if streak >= 2 { return 10 }   // 2 weeks
        return 0
    }
    
    private func getIconForAchievement(_ id: String) -> String {
        switch id {
        case let x where x.contains("review"): return "star.fill"
        case let x where x.contains("photo"): return "camera.fill"
        case let x where x.contains("detailed"): return "slider.horizontal.3"
        case let x where x.contains("streak"): return "flame.fill"
        case let x where x.contains("spots"): return "mappin.circle.fill"
        case let x where x.contains("friend"): return "person.2.fill"
        default: return "trophy.fill"
        }
    }
    
    private func getColorForAchievement(_ id: String) -> Color {
        switch id {
        case let x where x.contains("review"): return DesignSystem.Colors.primary
        case let x where x.contains("photo"): return DesignSystem.Colors.secondary
        case let x where x.contains("detailed"): return DesignSystem.Colors.accent
        case let x where x.contains("streak"): return DesignSystem.Colors.error
        case let x where x.contains("spots"): return DesignSystem.Colors.warning
        case let x where x.contains("friend"): return DesignSystem.Colors.info
        default: return DesignSystem.Colors.success
        }
    }
}

// MARK: - Supporting Models

struct ScoreBreakdownItem: Identifiable {
    let id = UUID()
    let title: String
    let points: Int
    let icon: String
    let color: Color
    let isAchievement: Bool
}
