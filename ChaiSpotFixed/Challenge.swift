import Foundation
import SwiftUI
import FirebaseFirestore
import FirebaseAuth

// 🎯 Challenge Model
struct Challenge: Identifiable, Codable {
    let id: String
    let title: String
    let description: String
    let type: ChallengeType
    let requirement: Int
    let reward: ChallengeReward
    let startDate: Date
    let endDate: Date
    let isActive: Bool
    let category: ChallengeCategory
    
    // Computed properties
    var isExpired: Bool {
        Date() > endDate
    }
    
    var daysRemaining: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date(), to: endDate)
        return max(0, components.day ?? 0)
    }
    
    var progressPercentage: Double {
        // This will be calculated based on user progress
        0.0
    }
}

// 🎯 Challenge Types
enum ChallengeType: String, Codable, CaseIterable {
    case reviewCount = "review_count"
    case photoCount = "photo_count"
    case streakDays = "streak_days"
    case newSpots = "new_spots"
    case friendInteractions = "friend_interactions"
    case badgeCollection = "badge_collection"
    case personalityExploration = "personality_exploration"
    
    var displayName: String {
        switch self {
        case .reviewCount: return "Review Challenge"
        case .photoCount: return "Photo Challenge"
        case .streakDays: return "Streak Challenge"
        case .newSpots: return "Exploration Challenge"
        case .friendInteractions: return "Social Challenge"
        case .badgeCollection: return "Badge Challenge"
        case .personalityExploration: return "Personality Challenge"
        }
    }
    
    var iconName: String {
        switch self {
        case .reviewCount: return "star.fill"
        case .photoCount: return "camera.fill"
        case .streakDays: return "flame.fill"
        case .newSpots: return "map.fill"
        case .friendInteractions: return "person.2.fill"
        case .badgeCollection: return "medal.fill"
        case .personalityExploration: return "person.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .reviewCount: return .orange
        case .photoCount: return .blue
        case .streakDays: return .red
        case .newSpots: return .green
        case .friendInteractions: return .purple
        case .badgeCollection: return .yellow
        case .personalityExploration: return .pink
        }
    }
}

// 🏆 Challenge Categories
enum ChallengeCategory: String, Codable, CaseIterable {
    case beginner = "beginner"
    case intermediate = "intermediate"
    case advanced = "advanced"
    case expert = "expert"
    
    var displayName: String {
        switch self {
        case .beginner: return "Beginner"
        case .intermediate: return "Intermediate"
        case .advanced: return "Advanced"
        case .expert: return "Expert"
        }
    }
    
    var color: Color {
        switch self {
        case .beginner: return .green
        case .intermediate: return .blue
        case .advanced: return .orange
        case .expert: return .red
        }
    }
}

// 🎁 Challenge Rewards
struct ChallengeReward: Codable {
    let type: RewardType
    let value: Int
    let description: String
    
    enum RewardType: String, Codable {
        case points = "points"
        case badge = "badge"
        case streak = "streak"
        case bonus = "bonus"
    }
}

// 🎯 User Challenge Progress
struct UserChallengeProgress: Identifiable, Codable {
    let id: String
    let challengeId: String
    let userId: String
    let currentProgress: Int
    let isCompleted: Bool
    let completedAt: Date?
    let rewardClaimed: Bool
    
    var progressPercentage: Double {
        // This will be calculated based on challenge requirement
        0.0
    }
}

// 🎯 Challenge Service
class ChallengeService: ObservableObject {
    @Published var activeChallenges: [Challenge] = []
    @Published var userProgress: [UserChallengeProgress] = []
    @Published var isLoading = false
    
    private let db = Firestore.firestore()
    private let auth = Auth.auth()
    
    // 🎯 Predefined monthly challenges
    static let monthlyChallenges: [Challenge] = [
        // January - New Year, New Chai
        Challenge(
            id: "jan_new_year_chai",
            title: "New Year, New Chai",
            description: "Start the year by trying 5 new chai spots",
            type: .newSpots,
            requirement: 5,
            reward: ChallengeReward(type: .points, value: 100, description: "100 bonus points"),
            startDate: Calendar.current.date(from: DateComponents(year: 2025, month: 1, day: 1)) ?? Date(),
            endDate: Calendar.current.date(from: DateComponents(year: 2025, month: 1, day: 31)) ?? Date(),
            isActive: true,
            category: .beginner
        ),
        
        // February - Love & Chai
        Challenge(
            id: "feb_love_chai",
            title: "Love & Chai",
            description: "Share 10 chai photos with your friends",
            type: .photoCount,
            requirement: 10,
            reward: ChallengeReward(type: .badge, value: 1, description: "Exclusive 'Chai Lover' badge"),
            startDate: Calendar.current.date(from: DateComponents(year: 2025, month: 2, day: 1)) ?? Date(),
            endDate: Calendar.current.date(from: DateComponents(year: 2025, month: 2, day: 28)) ?? Date(),
            isActive: true,
            category: .intermediate
        ),
        
        // March - Spring Chai Awakening
        Challenge(
            id: "mar_spring_chai",
            title: "Spring Chai Awakening",
            description: "Maintain a 7-day streak in March",
            type: .streakDays,
            requirement: 7,
            reward: ChallengeReward(type: .streak, value: 3, description: "+3 days to your current streak"),
            startDate: Calendar.current.date(from: DateComponents(year: 2025, month: 3, day: 1)) ?? Date(),
            endDate: Calendar.current.date(from: DateComponents(year: 2025, month: 3, day: 31)) ?? Date(),
            isActive: true,
            category: .beginner
        ),
        
        // April - Chai Explorer
        Challenge(
            id: "apr_chai_explorer",
            title: "Chai Explorer",
            description: "Visit 15 different chai spots",
            type: .newSpots,
            requirement: 15,
            reward: ChallengeReward(type: .badge, value: 1, description: "Rare 'Chai Explorer' badge"),
            startDate: Calendar.current.date(from: DateComponents(year: 2025, month: 4, day: 1)) ?? Date(),
            endDate: Calendar.current.date(from: DateComponents(year: 2025, month: 4, day: 30)) ?? Date(),
            isActive: true,
            category: .advanced
        ),
        
        // May - Social Chai
        Challenge(
            id: "may_social_chai",
            title: "Social Chai",
            description: "Interact with 20 friend reviews",
            type: .friendInteractions,
            requirement: 20,
            reward: ChallengeReward(type: .points, value: 150, description: "150 bonus points"),
            startDate: Calendar.current.date(from: DateComponents(year: 2025, month: 5, day: 1)) ?? Date(),
            endDate: Calendar.current.date(from: DateComponents(year: 2025, month: 5, day: 31)) ?? Date(),
            isActive: true,
            category: .intermediate
        ),
        
        // June - Summer Chai Quest
        Challenge(
            id: "jun_summer_chai",
            title: "Summer Chai Quest",
            description: "Write 25 detailed reviews with photos",
            type: .reviewCount,
            requirement: 25,
            reward: ChallengeReward(type: .badge, value: 1, description: "Epic 'Summer Chai Master' badge"),
            startDate: Calendar.current.date(from: DateComponents(year: 2025, month: 6, day: 1)) ?? Date(),
            endDate: Calendar.current.date(from: DateComponents(year: 2025, month: 6, day: 30)) ?? Date(),
            isActive: true,
            category: .expert
        ),
        
        // July - Independence Chai
        Challenge(
            id: "jul_independence_chai",
            title: "Independence Chai",
            description: "Try 10 unique chai types",
            type: .personalityExploration,
            requirement: 10,
            reward: ChallengeReward(type: .points, value: 200, description: "200 bonus points"),
            startDate: Calendar.current.date(from: DateComponents(year: 2025, month: 7, day: 1)) ?? Date(),
            endDate: Calendar.current.date(from: DateComponents(year: 2025, month: 7, day: 31)) ?? Date(),
            isActive: true,
            category: .intermediate
        ),
        
        // August - Back to School Chai
        Challenge(
            id: "aug_school_chai",
            title: "Back to School Chai",
            description: "Maintain a 14-day streak",
            type: .streakDays,
            requirement: 14,
            reward: ChallengeReward(type: .streak, value: 5, description: "+5 days to your current streak"),
            startDate: Calendar.current.date(from: DateComponents(year: 2025, month: 8, day: 1)) ?? Date(),
            endDate: Calendar.current.date(from: DateComponents(year: 2025, month: 8, day: 31)) ?? Date(),
            isActive: true,
            category: .advanced
        ),
        
        // September - Fall Chai Harvest
        Challenge(
            id: "sep_fall_chai",
            title: "Fall Chai Harvest",
            description: "Earn 5 new badges",
            type: .badgeCollection,
            requirement: 5,
            reward: ChallengeReward(type: .badge, value: 1, description: "Legendary 'Badge Collector' badge"),
            startDate: Calendar.current.date(from: DateComponents(year: 2025, month: 9, day: 1)) ?? Date(),
            endDate: Calendar.current.date(from: DateComponents(year: 2025, month: 9, day: 30)) ?? Date(),
            isActive: true,
            category: .expert
        ),
        
        // October - Spooky Chai
        Challenge(
            id: "oct_spooky_chai",
            title: "Spooky Chai",
            description: "Try 8 spiced chai variations",
            type: .personalityExploration,
            requirement: 8,
            reward: ChallengeReward(type: .points, value: 120, description: "120 bonus points"),
            startDate: Calendar.current.date(from: DateComponents(year: 2025, month: 10, day: 1)) ?? Date(),
            endDate: Calendar.current.date(from: DateComponents(year: 2025, month: 10, day: 31)) ?? Date(),
            isActive: true,
            category: .intermediate
        ),
        
        // November - Thankful Chai
        Challenge(
            id: "nov_thankful_chai",
            title: "Thankful Chai",
            description: "Share 15 chai moments with friends",
            type: .friendInteractions,
            requirement: 15,
            reward: ChallengeReward(type: .badge, value: 1, description: "Rare 'Grateful Chai Friend' badge"),
            startDate: Calendar.current.date(from: DateComponents(year: 2025, month: 11, day: 1)) ?? Date(),
            endDate: Calendar.current.date(from: DateComponents(year: 2025, month: 11, day: 30)) ?? Date(),
            isActive: true,
            category: .intermediate
        ),
        
        // December - Holiday Chai
        Challenge(
            id: "dec_holiday_chai",
            title: "Holiday Chai",
            description: "Complete 20 festive reviews",
            type: .reviewCount,
            requirement: 20,
            reward: ChallengeReward(type: .badge, value: 1, description: "Epic 'Holiday Chai Spirit' badge"),
            startDate: Calendar.current.date(from: DateComponents(year: 2025, month: 12, day: 1)) ?? Date(),
            endDate: Calendar.current.date(from: DateComponents(year: 2025, month: 12, day: 31)) ?? Date(),
            isActive: true,
            category: .advanced
        )
    ]
    
    init() {
        loadActiveChallenges()
        loadUserProgress()
    }
    
    // 🎯 Load active challenges
    func loadActiveChallenges() {
        let currentDate = Date()
        activeChallenges = Self.monthlyChallenges.filter { challenge in
            challenge.startDate <= currentDate && challenge.endDate >= currentDate
        }
    }
    
    // 👤 Load user progress
    func loadUserProgress() {
        guard let userId = auth.currentUser?.uid else { return }
        
        isLoading = true
        
        Task {
            let progress = await getUserChallengeProgress(userId: userId)
            
            await MainActor.run {
                self.userProgress = progress
                self.isLoading = false
            }
        }
    }
    
    // 🔄 Refresh challenges
    func refreshChallenges() {
        loadActiveChallenges()
        loadUserProgress()
    }
    
    // 🎯 Get user challenge progress
    private func getUserChallengeProgress(userId: String) async -> [UserChallengeProgress] {
        var progress: [UserChallengeProgress] = []
        
        for challenge in activeChallenges {
            let currentProgress = await calculateChallengeProgress(
                challenge: challenge,
                userId: userId
            )
            
            let isCompleted = currentProgress >= challenge.requirement
            let completedAt: Date? = isCompleted ? Date() : nil
            
            let userProgress = UserChallengeProgress(
                id: "\(userId)_\(challenge.id)",
                challengeId: challenge.id,
                userId: userId,
                currentProgress: currentProgress,
                isCompleted: isCompleted,
                completedAt: completedAt,
                rewardClaimed: false
            )
            
            progress.append(userProgress)
        }
        
        return progress
    }
    
    // 🧮 Calculate challenge progress
    private func calculateChallengeProgress(challenge: Challenge, userId: String) async -> Int {
        switch challenge.type {
        case .reviewCount:
            return await getReviewCount(userId: userId, since: challenge.startDate)
        case .photoCount:
            return await getPhotoCount(userId: userId, since: challenge.startDate)
        case .streakDays:
            return await getCurrentStreak(userId: userId)
        case .newSpots:
            return await getNewSpotsCount(userId: userId, since: challenge.startDate)
        case .friendInteractions:
            return await getFriendInteractionsCount(userId: userId, since: challenge.startDate)
        case .badgeCollection:
            return await getNewBadgesCount(userId: userId, since: challenge.startDate)
        case .personalityExploration:
            return await getUniqueChaiTypesCount(userId: userId, since: challenge.startDate)
        }
    }
    
    // 🔍 Helper functions for progress calculation
    private func getReviewCount(userId: String, since date: Date) async -> Int {
        do {
            let snapshot = try await db.collection("ratings")
                .whereField("userId", isEqualTo: userId)
                .whereField("timestamp", isGreaterThan: date)
                .getDocuments()
            
            return snapshot.documents.count
        } catch {
            print("Error fetching review count: \(error)")
            return 0
        }
    }
    
    private func getPhotoCount(userId: String, since date: Date) async -> Int {
        do {
            let snapshot = try await db.collection("ratings")
                .whereField("userId", isEqualTo: userId)
                .whereField("hasPhoto", isEqualTo: true)
                .whereField("timestamp", isGreaterThan: date)
                .getDocuments()
            
            return snapshot.documents.count
        } catch {
            print("Error fetching photo count: \(error)")
            return 0
        }
    }
    
    private func getCurrentStreak(userId: String) async -> Int {
        do {
            let document = try await db.collection("users").document(userId).getDocument()
            if let data = document.data() {
                return data["currentStreak"] as? Int ?? 0
            }
            return 0
        } catch {
            print("Error fetching current streak: \(error)")
            return 0
        }
    }
    
    private func getNewSpotsCount(userId: String, since date: Date) async -> Int {
        do {
            let snapshot = try await db.collection("ratings")
                .whereField("userId", isEqualTo: userId)
                .whereField("timestamp", isGreaterThan: date)
                .getDocuments()
            
            let uniqueSpots = Set(snapshot.documents.compactMap { $0.data()["spotId"] as? String })
            return uniqueSpots.count
        } catch {
            print("Error fetching new spots count: \(error)")
            return 0
        }
    }
    
    private func getFriendInteractionsCount(userId: String, since date: Date) async -> Int {
        // This would count reactions, comments, and other social interactions
        // For now, return a placeholder
        return 0
    }
    
    private func getNewBadgesCount(userId: String, since date: Date) async -> Int {
        // This would count badges earned since the challenge start date
        // For now, return a placeholder
        return 0
    }
    
    private func getUniqueChaiTypesCount(userId: String, since date: Date) async -> Int {
        do {
            let snapshot = try await db.collection("ratings")
                .whereField("userId", isEqualTo: userId)
                .whereField("timestamp", isGreaterThan: date)
                .getDocuments()
            
            let uniqueTypes = Set(snapshot.documents.compactMap { $0.data()["chaiType"] as? String })
            return uniqueTypes.count
        } catch {
            print("Error fetching unique chai types count: \(error)")
            return 0
        }
    }
    
    // 🎁 Claim challenge reward
    func claimReward(for challengeId: String) async -> Bool {
        guard let userId = auth.currentUser?.uid else { return false }
        
        // Find the challenge and user progress
        guard let challenge = activeChallenges.first(where: { $0.id == challengeId }),
              let progress = userProgress.first(where: { $0.challengeId == challengeId }) else {
            return false
        }
        
        // Check if challenge is completed and reward not claimed
        guard progress.isCompleted && !progress.rewardClaimed else {
            return false
        }
        
        // Apply the reward
        let success = await applyReward(reward: challenge.reward, userId: userId)
        
        if success {
            // Mark reward as claimed
            await markRewardAsClaimed(challengeId: challengeId, userId: userId)
        }
        
        return success
    }
    
    // 🎁 Apply challenge reward
    private func applyReward(reward: ChallengeReward, userId: String) async -> Bool {
        do {
            let userRef = db.collection("users").document(userId)
            
            switch reward.type {
            case .points:
                try await userRef.updateData([
                    "totalScore": FieldValue.increment(Int64(reward.value))
                ])
            case .streak:
                try await userRef.updateData([
                    "currentStreak": FieldValue.increment(Int64(reward.value))
                ])
            case .badge, .bonus:
                // These would be handled differently
                break
            }
            
            return true
        } catch {
            print("Error applying reward: \(error)")
            return false
        }
    }
    
    // ✅ Mark reward as claimed
    private func markRewardAsClaimed(challengeId: String, userId: String) async {
        // This would update the user's challenge progress
        // For now, we'll just refresh the data
        await MainActor.run {
            self.loadUserProgress()
        }
    }
}

// 🎯 Challenge Progress View
struct ChallengeProgressView: View {
    let challenge: Challenge
    let progress: UserChallengeProgress
    
    var body: some View {
        VStack(spacing: 12) {
            // Challenge header
            HStack {
                Image(systemName: challenge.type.iconName)
                    .foregroundColor(challenge.type.color)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(challenge.title)
                        .font(DesignSystem.Typography.bodyMedium)
                        .fontWeight(.semibold)
                    
                    Text(challenge.description)
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                // Category badge
                Text(challenge.category.rawValue.capitalized)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(challenge.category.color)
                    .cornerRadius(8)
            }
            
            // Progress bar
            VStack(spacing: 8) {
                HStack {
                    Text("\(progress.currentProgress)/\(challenge.requirement)")
                        .font(DesignSystem.Typography.bodySmall)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text("\(Int(progress.progressPercentage * 100))%")
                        .font(DesignSystem.Typography.bodySmall)
                        .foregroundColor(.secondary)
                }
                
                ProgressView(value: progress.progressPercentage)
                    .progressViewStyle(LinearProgressViewStyle(tint: challenge.type.color))
            }
            
            // Days remaining
            HStack {
                Image(systemName: "clock")
                    .foregroundColor(.secondary)
                    .font(.caption)
                
                Text("\(challenge.daysRemaining) days remaining")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // Reward info
                if progress.isCompleted && !progress.rewardClaimed {
                    Text("🎁 Reward ready!")
                        .font(DesignSystem.Typography.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.green)
                } else if progress.isCompleted && progress.rewardClaimed {
                    Text("✅ Completed")
                        .font(DesignSystem.Typography.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.green)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(challenge.type.color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}
