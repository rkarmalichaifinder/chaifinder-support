import Foundation
import FirebaseFirestore
import FirebaseAuth

class GamificationService: ObservableObject {
    @Published var userBadges: [Badge] = []
    @Published var userAchievements: [Achievement] = []
    @Published var currentStreak: Int = 0
    @Published var longestStreak: Int = 0
    @Published var totalScore: Int = 0
    
    private let db = Firestore.firestore()
    private let auth = Auth.auth()
    private let notificationService = NotificationService.shared
    
    // 🎖️ Predefined badges
    static let availableBadges: [Badge] = [
        // First Steps
        Badge(id: "first_review", name: "First Sip", description: "Rate your first chai spot", iconName: "cup.and.saucer.fill", category: .firstSteps, requirement: 1, rarity: .common),
        Badge(id: "first_photo", name: "Chai Photographer", description: "Upload your first chai photo", iconName: "camera.fill", category: .firstSteps, requirement: 1, rarity: .common),
        Badge(id: "taste_setup", name: "Taste Master", description: "Complete your taste profile", iconName: "person.fill.checkmark", category: .firstSteps, requirement: 1, rarity: .common),
        
        // Exploration
        Badge(id: "5_spots", name: "Chai Explorer", description: "Visit 5 different chai spots", iconName: "map.fill", category: .exploration, requirement: 5, rarity: .common),
        Badge(id: "10_spots", name: "Chai Adventurer", description: "Visit 10 different chai spots", iconName: "map.fill", category: .exploration, requirement: 10, rarity: .rare),
        Badge(id: "25_spots", name: "Chai Pioneer", description: "Visit 25 different chai spots", iconName: "map.fill", category: .exploration, requirement: 25, rarity: .epic),
        Badge(id: "50_spots", name: "Chai Legend", description: "Visit 50 different chai spots", iconName: "map.fill", category: .exploration, requirement: 50, rarity: .legendary),
        
        // Social
        Badge(id: "first_friend", name: "Social Butterfly", description: "Add your first friend", iconName: "person.2.fill", category: .social, requirement: 1, rarity: .common),
        Badge(id: "10_friends", name: "Chai Community", description: "Connect with 10 friends", iconName: "person.3.fill", category: .social, requirement: 10, rarity: .rare),
        Badge(id: "first_reaction", name: "Supportive Friend", description: "React to a friend's review", iconName: "heart.fill", category: .social, requirement: 1, rarity: .common),
        
        // Mastery
        Badge(id: "7_day_streak", name: "Week Warrior", description: "Maintain a 7-day review streak", iconName: "flame.fill", category: .mastery, requirement: 7, rarity: .rare),
        Badge(id: "30_day_streak", name: "Month Master", description: "Maintain a 30-day review streak", iconName: "flame.fill", category: .mastery, requirement: 30, rarity: .epic),
        Badge(id: "100_reviews", name: "Review Master", description: "Write 100 reviews", iconName: "pencil.circle.fill", category: .mastery, requirement: 100, rarity: .epic),
        
        // Seasonal
        Badge(id: "summer_chai", name: "Summer Sipper", description: "Rate chai during summer months", iconName: "sun.max.fill", category: .seasonal, requirement: 1, rarity: .common),
        Badge(id: "winter_chai", name: "Winter Warmer", description: "Rate chai during winter months", iconName: "snowflake", category: .seasonal, requirement: 1, rarity: .common)
    ]
    
    // 🏆 Predefined achievements
    static let availableAchievements: [Achievement] = [
        Achievement(id: "first_review", name: "First Review", description: "Complete your first chai review", points: 25),
        Achievement(id: "photo_upload", name: "Photo Enthusiast", description: "Upload a photo with your review", points: 15),
        Achievement(id: "detailed_review", name: "Detail Oriented", description: "Complete all rating fields", points: 20),
        Achievement(id: "daily_streak_3", name: "Getting Started", description: "Maintain a 3-day streak", points: 30),
        Achievement(id: "daily_streak_7", name: "Week Warrior", description: "Maintain a 7-day streak", points: 50),
        Achievement(id: "daily_streak_30", name: "Month Master", description: "Maintain a 30-day streak", points: 100),
        Achievement(id: "10_reviews", name: "Reviewer", description: "Write 10 reviews", points: 40),
        Achievement(id: "50_reviews", name: "Pro Reviewer", description: "Write 50 reviews", points: 100),
        Achievement(id: "100_reviews", name: "Review Master", description: "Write 100 reviews", points: 200),
        Achievement(id: "5_spots", name: "Explorer", description: "Visit 5 different spots", points: 50),
        Achievement(id: "10_spots", name: "Adventurer", description: "Visit 10 different spots", points: 100),
        Achievement(id: "25_spots", name: "Pioneer", description: "Visit 25 different spots", points: 200),
        Achievement(id: "first_friend", name: "Social", description: "Add your first friend", points: 25),
        Achievement(id: "10_friends", name: "Community Builder", description: "Connect with 10 friends", points: 100)
    ]
    
    init() {
        loadUserGamificationData()
    }
    

    
    // 🔥 Calculate and update weekly streak
    func updateWeeklyStreak(lastWeekReviewCount: Int, targetPerWeek: Int = 3) async -> (currentStreak: Int, longestStreak: Int, isNewStreak: Bool) {
        var newCurrentStreak = 0
        var newLongestStreak = 0
        var isNewStreak = false
        
        if lastWeekReviewCount >= targetPerWeek {
            // Weekly goal met - extend streak
            newCurrentStreak = currentStreak + 1
            isNewStreak = true
            
            // Check for streak milestones and trigger notifications
            checkStreakMilestones(newStreak: newCurrentStreak)
            
            // Update total score after streak change
            await updateTotalScore()
        } else {
            // Weekly goal not met - reset streak
            newCurrentStreak = 0
        }
        
        newLongestStreak = max(longestStreak, newCurrentStreak)
        
        return (newCurrentStreak, newLongestStreak, isNewStreak)
    }
    
    // 🔥 Calculate and update streak (keeping for backward compatibility)
    func updateStreak(lastReviewDate: Date) async -> (currentStreak: Int, longestStreak: Int, isNewStreak: Bool) {
        let calendar = Calendar.current
        let now = Date()
        
        // Check if this is a consecutive day
        let daysSinceLastReview = calendar.dateComponents([.day], from: lastReviewDate, to: now).day ?? 0
        
        var newCurrentStreak = 1
        var newLongestStreak = 0
        var isNewStreak = false
        
        if daysSinceLastReview == 1 {
            // Consecutive day - extend streak
            newCurrentStreak = currentStreak + 1
            isNewStreak = true
            
            // Check for streak milestones and trigger notifications
            checkStreakMilestones(newStreak: newCurrentStreak)
            
            // Update total score after streak change
            await updateTotalScore()
        } else if daysSinceLastReview == 0 {
            // Same day - maintain current streak
            newCurrentStreak = currentStreak
        } else {
            // Gap in streak - reset to 1
            newCurrentStreak = 1
        }
        
        newLongestStreak = max(longestStreak, newCurrentStreak)
        
        return (newCurrentStreak, newLongestStreak, isNewStreak)
    }
    
    // 🎖️ Check and award badges
    func checkAndAwardBadges(userProfile: UserProfile, newRating: Rating) async -> [Badge] {
        var newlyAwardedBadges: [Badge] = []
        
        for badge in Self.availableBadges {
            // Skip if user already has this badge
            if userProfile.badges.contains(badge.id) {
                continue
            }
            
            // Check if badge requirements are met
            if shouldAwardBadge(badge: badge, userProfile: userProfile, newRating: newRating) {
                var awardedBadge = badge
                awardedBadge.unlockedAt = Date()
                newlyAwardedBadges.append(awardedBadge)
                
                // Add to user's badges
                await awardBadgeToUser(badgeId: badge.id)
                
                // Trigger notification for badge unlock
                DispatchQueue.main.async {
                    self.notificationService.notifyBadgeUnlocked(badge: awardedBadge)
                }
                
                // Update total score after awarding badge
                await updateTotalScore()
            }
        }
        
        return newlyAwardedBadges
    }
    
    // 🏆 Check and award achievements
    func checkAndAwardAchievements(userProfile: UserProfile, newRating: Rating) async -> [Achievement] {
        var newlyAwardedAchievements: [Achievement] = []
        
        for achievement in Self.availableAchievements {
            // Skip if user already has this achievement
            if userProfile.achievements[achievement.id] != nil {
                continue
            }
            
            // Check if achievement requirements are met
            if shouldAwardAchievement(achievement: achievement, userProfile: userProfile, newRating: newRating) {
                await awardAchievementToUser(achievementId: achievement.id)
                newlyAwardedAchievements.append(achievement)
                
                // Trigger notification for achievement unlock
                DispatchQueue.main.async {
                    self.notificationService.notifyAchievementUnlocked(achievement: achievement)
                }
                
                // Update total score after awarding achievement
                await updateTotalScore()
            }
        }
        
        return newlyAwardedAchievements
    }
    
    // 🔥 Check for streak milestones and trigger notifications
    private func checkStreakMilestones(newStreak: Int) {
        let milestoneStreaks = [3, 7, 14, 30, 50, 100]
        
        if milestoneStreaks.contains(newStreak) {
            // Trigger streak milestone notification
            notificationService.scheduleGamificationNotification(
                type: .streakMilestone,
                delay: 2.0
            )
            
            // Schedule daily streak reminder if not already scheduled
            if newStreak >= 3 {
                notificationService.scheduleStreakReminder()
            }
        }
    }
    
    // 🎯 Check if badge should be awarded
    private func shouldAwardBadge(badge: Badge, userProfile: UserProfile, newRating: Rating) -> Bool {
        switch badge.id {
        case "first_review":
            return userProfile.totalReviews == 1
        case "first_photo":
            return newRating.hasPhoto && userProfile.totalReviews == 1
        case "taste_setup":
            return userProfile.hasTasteSetup
        case "5_spots":
            return userProfile.spotsVisited >= 5
        case "10_spots":
            return userProfile.spotsVisited >= 10
        case "25_spots":
            return userProfile.spotsVisited >= 25
        case "50_spots":
            return userProfile.spotsVisited >= 50
        case "first_friend":
            return (userProfile.friends?.count ?? 0) >= 1
        case "10_friends":
            return (userProfile.friends?.count ?? 0) >= 10
        case "first_reaction":
            return !newRating.reactions.isEmpty
        case "7_day_streak":
            return userProfile.currentStreak >= 7
        case "30_day_streak":
            return userProfile.currentStreak >= 30
        case "100_reviews":
            return userProfile.totalReviews >= 100
        case "summer_chai":
            let month = Calendar.current.component(.month, from: Date())
            return month >= 6 && month <= 8
        case "winter_chai":
            let month = Calendar.current.component(.month, from: Date())
            return month == 12 || month <= 2
        default:
            return false
        }
    }
    
    // 🎯 Check if achievement should be awarded
    private func shouldAwardAchievement(achievement: Achievement, userProfile: UserProfile, newRating: Rating) -> Bool {
        switch achievement.id {
        case "first_review":
            return userProfile.totalReviews == 1
        case "photo_upload":
            return newRating.hasPhoto
        case "detailed_review":
            return newRating.creaminessRating != nil && newRating.chaiStrengthRating != nil && 
                   newRating.flavorNotes != nil && newRating.chaiType != nil
        case "daily_streak_3":
            return userProfile.currentStreak >= 3
        case "daily_streak_7":
            return userProfile.currentStreak >= 7
        case "daily_streak_30":
            return userProfile.currentStreak >= 30
        case "10_reviews":
            return userProfile.totalReviews >= 10
        case "50_reviews":
            return userProfile.totalReviews >= 50
        case "100_reviews":
            return userProfile.totalReviews >= 100
        case "5_spots":
            return userProfile.spotsVisited >= 5
        case "10_spots":
            return userProfile.spotsVisited >= 10
        case "25_spots":
            return userProfile.spotsVisited >= 25
        case "first_friend":
            return (userProfile.friends?.count ?? 0) >= 1
        case "10_friends":
            return (userProfile.friends?.count ?? 0) >= 10
        default:
            return false
        }
    }
    
    // 💾 Award badge to user in Firestore
    private func awardBadgeToUser(badgeId: String) async {
        guard let userId = auth.currentUser?.uid else { return }
        
        do {
            try await db.collection("users").document(userId).updateData([
                "badges": FieldValue.arrayUnion([badgeId])
            ])
        } catch {
            print("Error awarding badge: \(error)")
        }
    }
    
    // 💾 Award achievement to user in Firestore
    private func awardAchievementToUser(achievementId: String) async {
        guard let userId = auth.currentUser?.uid else { return }
        
        do {
            try await db.collection("users").document(userId).updateData([
                "achievements.\(achievementId)": Date()
            ])
        } catch {
            print("Error awarding achievement: \(error)")
        }
    }
    
    // 📱 Load user gamification data
    private func loadUserGamificationData() {
        guard let userId = auth.currentUser?.uid else { return }
        
        db.collection("users").document(userId).addSnapshotListener { [weak self] documentSnapshot, error in
            guard let document = documentSnapshot else {
                print("Error fetching user data: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            if let data = document.data() {
                DispatchQueue.main.async {
                    self?.currentStreak = data["currentStreak"] as? Int ?? 0
                    self?.longestStreak = data["longestStreak"] as? Int ?? 0
                    self?.totalScore = data["totalScore"] as? Int ?? 0
                    
                    // Load badges
                    if let badgeIds = data["badges"] as? [String] {
                        self?.userBadges = Self.availableBadges.filter { badgeIds.contains($0.id) }
                    }
                    
                    // Load achievements
                    if let achievements = data["achievements"] as? [String: Timestamp] {
                        self?.userAchievements = Self.availableAchievements.compactMap { achievement in
                            if let timestamp = achievements[achievement.id] {
                                var updatedAchievement = achievement
                                updatedAchievement.unlockedAt = timestamp.dateValue()
                                return updatedAchievement
                            }
                            return nil
                        }
                    }
                }
            }
        }
    }
    
    // 🔄 Refresh gamification data
    func refreshData() {
        loadUserGamificationData()
    }
    
    // 🎯 Calculate total score from all user activities
    func calculateTotalScore() -> Int {
        var total = 0
        
        // Add points from all achievements
        for achievement in userAchievements {
            total += achievement.points
        }
        
        // Add points from badges (if badges have point values)
        total += userBadges.count * 10 // 10 points per badge
        
        // Add points from current streak
        total += currentStreak * 5 // 5 points per week of streak
        
        // Add points from longest streak milestone
        if longestStreak >= 52 { total += 100 }      // 1 year
        else if longestStreak >= 26 { total += 75 }  // 6 months
        else if longestStreak >= 12 { total += 50 }  // 3 months
        else if longestStreak >= 8 { total += 25 }   // 2 months
        else if longestStreak >= 4 { total += 15 }   // 1 month
        else if longestStreak >= 2 { total += 10 }   // 2 weeks
        
        return total
    }
    
    // 🔄 Update total score in Firestore
    func updateTotalScore() async {
        guard let userId = auth.currentUser?.uid else { return }
        
        let newTotalScore = calculateTotalScore()
        
        do {
            try await db.collection("users").document(userId).updateData([
                "totalScore": newTotalScore
            ])
            
            await MainActor.run {
                self.totalScore = newTotalScore
            }
            
            print("✅ Updated total score to: \(newTotalScore)")
        } catch {
            print("❌ Error updating total score: \(error)")
        }
    }
    
    // 🔄 Update total score locally (non-async version)
    func updateTotalScoreLocally() {
        let newTotalScore = calculateTotalScore()
        self.totalScore = newTotalScore
        print("✅ Updated local total score to: \(newTotalScore)")
    }
    
    // 🎯 Trigger weekly challenge notification
    func triggerWeeklyChallenge() {
        notificationService.scheduleGamificationNotification(
            type: .weeklyChallenge,
            delay: 1.0
        )
    }
    
    // 👥 Trigger friend activity notification
    func triggerFriendActivity(friendName: String, activity: String) {
        notificationService.notifyFriendActivity(friendName: friendName, activity: activity)
    }
}
