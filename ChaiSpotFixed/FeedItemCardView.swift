import SwiftUI

// MARK: - Feed Item Card View
struct FeedItemCardView: View {
    let item: FeedItem
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                // Header with user info and timestamp
                headerSection
                
                // Content based on item type
                contentSection
                
                // Footer with actions
                footerSection
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
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                    .stroke(item.isRead ? Color.clear : DesignSystem.Colors.primary.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            // Activity icon
            Image(systemName: item.type.icon)
                .foregroundColor(iconColor)
                .font(.system(size: 16, weight: .medium))
                .frame(width: 24, height: 24)
                .background(iconColor.opacity(0.1))
                .cornerRadius(6)
            
            // User info
            VStack(alignment: .leading, spacing: 2) {
                Text(item.username)
                    .font(DesignSystem.Typography.bodyMedium)
                    .fontWeight(.semibold)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                
                Text(activityDescription)
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
            
            Spacer()
            
            // Timestamp
            Text(item.timestamp, style: .relative)
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.textSecondary)
        }
    }
    
    // MARK: - Content Section
    private var contentSection: some View {
        Group {
            switch item.type {
            case .review:
                if let reviewItem = item as? ReviewFeedItem {
                    ReviewContentCard(review: reviewItem)
                }
            case .newUser:
                if let userItem = item as? NewUserFeedItem {
                    NewUserContentCard(user: userItem)
                }
            case .newSpot:
                if let spotItem = item as? NewSpotFeedItem {
                    NewSpotContentCard(spot: spotItem)
                }
            case .achievement:
                if let achievementItem = item as? AchievementFeedItem {
                    AchievementContentCard(achievement: achievementItem)
                }
            case .friendActivity:
                if let activityItem = item as? FriendActivityFeedItem {
                    FriendActivityContentCard(activity: activityItem)
                }
            case .weeklyChallenge:
                if let challengeItem = item as? WeeklyChallengeFeedItem {
                    WeeklyChallengeContentCard(challenge: challengeItem)
                }
            case .weeklyRanking:
                if let rankingItem = item as? WeeklyRankingFeedItem {
                    WeeklyRankingContentCard(ranking: rankingItem)
                }
            }
        }
    }
    
    // MARK: - Footer Section
    private var footerSection: some View {
        HStack {
            // Action buttons based on item type
            actionButtons
            
            Spacer()
            
            // Read indicator
            if !item.isRead {
                Circle()
                    .fill(DesignSystem.Colors.primary)
                    .frame(width: 8, height: 8)
            }
        }
    }
    
    // MARK: - Computed Properties
    private var iconColor: Color {
        switch item.type {
        case .review: return DesignSystem.Colors.primary
        case .newUser: return DesignSystem.Colors.info
        case .newSpot: return DesignSystem.Colors.secondary
        case .achievement: return .orange
        case .friendActivity: return DesignSystem.Colors.success
        case .weeklyChallenge: return .red
        case .weeklyRanking: return .purple
        }
    }
    
    private var activityDescription: String {
        switch item.type {
        case .review: return "reviewed a chai spot"
        case .newUser: return "joined chai finder"
        case .newSpot: return "discovered a new spot"
        case .achievement: return "earned an achievement"
        case .friendActivity: return "did something new"
        case .weeklyChallenge: return "updated weekly challenge"
        case .weeklyRanking: return "got a new ranking"
        }
    }
    
    private var actionButtons: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            switch item.type {
            case .review:
                if let reviewItem = item as? ReviewFeedItem {
                    ReviewActionButtons(review: reviewItem)
                }
            case .newUser:
                Button("Add Friend") {
                    // TODO: Implement add friend action
                }
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.primary)
            case .newSpot:
                Button("View Spot") {
                    // TODO: Implement view spot action
                }
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.primary)
            case .achievement:
                Button("View Achievement") {
                    // TODO: Implement view achievement action
                }
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.primary)
            case .friendActivity:
                Button("View Activity") {
                    // TODO: Implement view activity action
                }
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.primary)
            case .weeklyChallenge:
                Button("Join Challenge") {
                    // TODO: Implement join challenge action
                }
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.primary)
            case .weeklyRanking:
                Button("View Ranking") {
                    // TODO: Implement view ranking action
                }
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.primary)
            }
        }
    }
}

// MARK: - Content Card Views

struct ReviewContentCard: View {
    let review: ReviewFeedItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            // Spot name
            Text(review.spotName)
                .font(DesignSystem.Typography.bodyMedium)
                .fontWeight(.semibold)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            
            // Rating
            HStack(spacing: 4) {
                ForEach(1...5, id: \.self) { i in
                    Image(systemName: i <= review.rating ? "star.fill" : "star")
                        .foregroundColor(i <= review.rating ? .yellow : DesignSystem.Colors.textSecondary)
                        .font(.caption)
                }
                Text("(\(review.rating)/5)")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
            
            // Comment
            if let comment = review.comment, !comment.isEmpty {
                Text(comment)
                    .font(DesignSystem.Typography.bodySmall)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .lineLimit(3)
            }
            
            // Photo indicator
            if let photoURL = review.photoURL, !photoURL.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "camera.fill")
                        .foregroundColor(.orange)
                        .font(.caption2)
                    Text("Photo included")
                        .font(DesignSystem.Typography.caption2)
                        .foregroundColor(.orange)
                }
            }
        }
    }
}

struct NewUserContentCard: View {
    let user: NewUserFeedItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Welcome to chai finder! 🫖")
                .font(DesignSystem.Typography.bodyMedium)
                .fontWeight(.semibold)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            
            if let bio = user.bio, !bio.isEmpty {
                Text(bio)
                    .font(DesignSystem.Typography.bodySmall)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .lineLimit(2)
            }
        }
    }
}

struct NewSpotContentCard: View {
    let spot: NewSpotFeedItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("New chai spot discovered! 📍")
                .font(DesignSystem.Typography.bodyMedium)
                .fontWeight(.semibold)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            
            Text(spot.spotName)
                .font(DesignSystem.Typography.bodyMedium)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            
            Text(spot.spotAddress)
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.textSecondary)
            
            if !spot.chaiTypes.isEmpty {
                HStack {
                    Text("Chai types:")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    
                    ForEach(spot.chaiTypes.prefix(3), id: \.self) { chaiType in
                        Text(chaiType)
                            .font(DesignSystem.Typography.caption2)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(DesignSystem.Colors.primary)
                            .cornerRadius(4)
                    }
                    
                    if spot.chaiTypes.count > 3 {
                        Text("+\(spot.chaiTypes.count - 3) more")
                            .font(DesignSystem.Typography.caption2)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                }
            }
        }
    }
}

struct AchievementContentCard: View {
    let achievement: AchievementFeedItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack {
                Image(systemName: achievement.achievementIcon)
                    .foregroundColor(.orange)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(achievement.achievementName)
                        .font(DesignSystem.Typography.bodyMedium)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    
                    Text("+\(achievement.pointsEarned) points")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(.orange)
                        .fontWeight(.medium)
                }
            }
            
            Text(achievement.achievementDescription)
                .font(DesignSystem.Typography.bodySmall)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .lineLimit(2)
        }
    }
}

struct FriendActivityContentCard: View {
    let activity: FriendActivityFeedItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text(activity.activityDescription)
                .font(DesignSystem.Typography.bodyMedium)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            
            if let spotName = activity.relatedSpotName {
                Text("at \(spotName)")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
        }
    }
}

struct WeeklyChallengeContentCard: View {
    let challenge: WeeklyChallengeFeedItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text(challenge.challengeName)
                .font(DesignSystem.Typography.bodyMedium)
                .fontWeight(.semibold)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            
            Text(challenge.challengeDescription)
                .font(DesignSystem.Typography.bodySmall)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .lineLimit(2)
            
            // Progress bar
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Progress:")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    
                    Spacer()
                    
                    Text("\(challenge.progress)/\(challenge.target)")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                
                ProgressView(value: Double(challenge.progress), total: Double(challenge.target))
                    .progressViewStyle(LinearProgressViewStyle(tint: .red))
                    .scaleEffect(y: 0.5)
            }
            
            if !challenge.reward.isEmpty {
                Text("Reward: \(challenge.reward)")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(.orange)
                    .fontWeight(.medium)
            }
        }
    }
}

struct WeeklyRankingContentCard: View {
    let ranking: WeeklyRankingFeedItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack {
                Text("🏆 Weekly Ranking")
                    .font(DesignSystem.Typography.bodyMedium)
                    .fontWeight(.semibold)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                
                Spacer()
                
                Text("Rank #\(ranking.rank)")
                    .font(DesignSystem.Typography.bodyMedium)
                    .fontWeight(.bold)
                    .foregroundColor(.purple)
            }
            
            Text("Out of \(ranking.totalUsers) users")
                .font(DesignSystem.Typography.bodySmall)
                .foregroundColor(DesignSystem.Colors.textSecondary)
            
            if let previousRank = ranking.previousRank {
                let rankChange = previousRank - ranking.rank
                let changeText = rankChange > 0 ? "+\(rankChange)" : "\(rankChange)"
                let changeColor: Color = rankChange > 0 ? .green : (rankChange < 0 ? .red : .orange)
                
                Text("Rank change: \(changeText)")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(changeColor)
                    .fontWeight(.medium)
            }
            
            Text("Score: \(ranking.score) points")
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.textSecondary)
        }
    }
}

// MARK: - Action Buttons

struct ReviewActionButtons: View {
    let review: ReviewFeedItem
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Button(action: {
                // TODO: Implement like action
            }) {
                HStack(spacing: 2) {
                    Image(systemName: "hand.thumbsup")
                        .font(.caption)
                    Text("\(review.likes)")
                        .font(DesignSystem.Typography.caption)
                }
            }
            .foregroundColor(DesignSystem.Colors.textSecondary)
            
            Button(action: {
                // TODO: Implement dislike action
            }) {
                HStack(spacing: 2) {
                    Image(systemName: "hand.thumbsdown")
                        .font(.caption)
                    Text("\(review.dislikes)")
                        .font(DesignSystem.Typography.caption)
                }
            }
            .foregroundColor(DesignSystem.Colors.textSecondary)
            
            Button("View Spot") {
                // TODO: Implement view spot action
            }
            .font(DesignSystem.Typography.caption)
            .foregroundColor(DesignSystem.Colors.primary)
        }
    }
}
