import Foundation
import FirebaseFirestore
import FirebaseAuth

class WeeklyChallengeService: ObservableObject {
    @Published var currentChallenge: WeeklyChallenge?
    @Published var userProgress: [String: Int] = [:]
    @Published var isChallengeActive = false
    
    private let db = Firestore.firestore()
    private let auth = Auth.auth()
    private let notificationService = NotificationService.shared
    
    // MARK: - Weekly Challenge Model
    struct WeeklyChallenge: Identifiable, Codable {
        let id: String
        let title: String
        let description: String
        let type: ChallengeType
        let target: Int
        let reward: Int
        let startDate: Date
        let endDate: Date
        let isActive: Bool
        
        enum ChallengeType: String, Codable, CaseIterable {
            case rateSpots = "rate_spots"
            case uploadPhotos = "upload_photos"
            case visitNewSpots = "visit_new_spots"
            case maintainStreak = "maintain_streak"
            case addFriends = "add_friends"
            case detailedReviews = "detailed_reviews"
            
            var icon: String {
                switch self {
                case .rateSpots: return "cup.and.saucer.fill"
                case .uploadPhotos: return "camera.fill"
                case .visitNewSpots: return "map.fill"
                case .maintainStreak: return "flame.fill"
                case .addFriends: return "person.2.fill"
                case .detailedReviews: return "text.bubble.fill"
                }
            }
            
            var color: String {
                switch self {
                case .rateSpots: return "orange"
                case .uploadPhotos: return "blue"
                case .visitNewSpots: return "green"
                case .maintainStreak: return "red"
                case .addFriends: return "purple"
                case .detailedReviews: return "indigo"
                }
            }
        }
    }
    
    init() {
        loadCurrentChallenge()
        loadUserProgress()
    }
    
    // MARK: - Challenge Management
    
    func loadCurrentChallenge() {
        let now = Date()
        
        // Check if there's an active challenge
        db.collection("weeklyChallenges")
            .whereField("isActive", isEqualTo: true)
            .whereField("startDate", isLessThanOrEqualTo: now)
            .whereField("endDate", isGreaterThan: now)
            .getDocuments { [weak self] snapshot, error in
                if let error = error {
                    print("❌ Error loading challenge: \(error.localizedDescription)")
                    return
                }
                
                if let document = snapshot?.documents.first {
                    do {
                        let challenge = try document.data(as: WeeklyChallenge.self)
                        DispatchQueue.main.async {
                            self?.currentChallenge = challenge
                            self?.isChallengeActive = true
                        }
                    } catch {
                        print("❌ Error decoding challenge: \(error.localizedDescription)")
                    }
                } else {
                    // Create a new challenge if none exists
                    DispatchQueue.main.async {
                        self?.createNewChallenge()
                    }
                }
            }
    }
    
    private func createNewChallenge() {
        let now = Date()
        let calendar = Calendar.current
        
        // Create a challenge that starts next Monday and ends Sunday
        let nextMonday = calendar.nextDate(after: now, matching: DateComponents(weekday: 2), matchingPolicy: .nextTime) ?? now
        let endDate = calendar.date(byAdding: .day, value: 6, to: nextMonday) ?? now
        
        let challengeTypes = WeeklyChallenge.ChallengeType.allCases
        let randomType = challengeTypes.randomElement() ?? .rateSpots
        
        let challenge = WeeklyChallenge(
            id: UUID().uuidString,
            title: generateChallengeTitle(for: randomType),
            description: generateChallengeDescription(for: randomType),
            type: randomType,
            target: generateChallengeTarget(for: randomType),
            reward: generateChallengeReward(for: randomType),
            startDate: nextMonday,
            endDate: endDate,
            isActive: true
        )
        
        // Save to Firestore
        saveChallenge(challenge)
        
        // Set as current challenge
        currentChallenge = challenge
        isChallengeActive = true
        
        // Notify users about new challenge
        notifyNewChallenge(challenge)
    }
    
    private func generateChallengeTitle(for type: WeeklyChallenge.ChallengeType) -> String {
        switch type {
        case .rateSpots:
            return "Chai Rating Champion"
        case .uploadPhotos:
            return "Chai Photographer"
        case .visitNewSpots:
            return "Chai Explorer"
        case .maintainStreak:
            return "Streak Master"
        case .addFriends:
            return "Social Butterfly"
        case .detailedReviews:
            return "Detail Master"
        }
    }
    
    private func generateChallengeDescription(for type: WeeklyChallenge.ChallengeType) -> String {
        switch type {
        case .rateSpots:
            return "Rate 5 chai spots this week to become a rating champion!"
        case .uploadPhotos:
            return "Upload photos with 3 of your reviews this week!"
        case .visitNewSpots:
            return "Visit 3 new chai spots you've never been to before!"
        case .maintainStreak:
            return "Maintain a 5-day rating streak this week!"
        case .addFriends:
            return "Add 2 new friends to expand your chai community!"
        case .detailedReviews:
            return "Write 4 detailed reviews with all fields completed!"
        }
    }
    
    private func generateChallengeTarget(for type: WeeklyChallenge.ChallengeType) -> Int {
        switch type {
        case .rateSpots: return 5
        case .uploadPhotos: return 3
        case .visitNewSpots: return 3
        case .maintainStreak: return 5
        case .addFriends: return 2
        case .detailedReviews: return 4
        }
    }
    
    private func generateChallengeReward(for type: WeeklyChallenge.ChallengeType) -> Int {
        switch type {
        case .rateSpots: return 50
        case .uploadPhotos: return 75
        case .visitNewSpots: return 100
        case .maintainStreak: return 150
        case .addFriends: return 60
        case .detailedReviews: return 80
        }
    }
    
    private func saveChallenge(_ challenge: WeeklyChallenge) {
        do {
            try db.collection("weeklyChallenges").document(challenge.id).setData(from: challenge)
            print("✅ Weekly challenge saved: \(challenge.title)")
        } catch {
            print("❌ Error saving challenge: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Progress Tracking
    
    func loadUserProgress() {
        guard let userId = auth.currentUser?.uid,
              let challengeId = currentChallenge?.id else { return }
        
        db.collection("users").document(userId)
            .collection("challengeProgress")
            .document(challengeId)
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    print("❌ Error loading progress: \(error.localizedDescription)")
                    return
                }
                
                if let data = snapshot?.data() {
                    DispatchQueue.main.async {
                        self?.userProgress = data["progress"] as? [String: Int] ?? [:]
                    }
                }
            }
    }
    
    func updateProgress(for action: WeeklyChallenge.ChallengeType, increment: Int = 1) {
        guard let userId = auth.currentUser?.uid,
              let challengeId = currentChallenge?.id else { return }
        
        let currentProgress = userProgress[action.rawValue] ?? 0
        let newProgress = currentProgress + increment
        
        // Update local progress
        userProgress[action.rawValue] = newProgress
        
        // Update Firestore
        db.collection("users").document(userId)
            .collection("challengeProgress")
            .document(challengeId)
            .setData([
                "progress": userProgress,
                "lastUpdated": Timestamp()
            ], merge: true) { error in
                if let error = error {
                    print("❌ Error updating progress: \(error.localizedDescription)")
                } else {
                    print("✅ Progress updated: \(action.rawValue) = \(newProgress)")
                    
                    // Check if challenge is completed
                    self.checkChallengeCompletion()
                }
            }
    }
    
    private func checkChallengeCompletion() {
        guard let challenge = currentChallenge else { return }
        
        let currentProgress = userProgress[challenge.type.rawValue] ?? 0
        
        if currentProgress >= challenge.target {
            // Challenge completed!
            completeChallenge(challenge)
        }
    }
    
    private func completeChallenge(_ challenge: WeeklyChallenge) {
        guard let userId = auth.currentUser?.uid else { return }
        
        // Award points
        let db = Firestore.firestore()
        db.collection("users").document(userId).updateData([
            "totalScore": FieldValue.increment(Int64(challenge.reward))
        ]) { error in
            if let error = error {
                print("❌ Error awarding challenge points: \(error.localizedDescription)")
            } else {
                print("✅ Challenge completed! Awarded \(challenge.reward) points")
                
                // Notify user
                DispatchQueue.main.async {
                    self.notificationService.scheduleGamificationNotification(
                        type: .weeklyChallenge,
                        delay: 1.0
                    )
                }
            }
        }
    }
    
    // MARK: - Notifications
    
    private func notifyNewChallenge(_ challenge: WeeklyChallenge) {
        // Send push notification to all users about new challenge
        // This would typically be done server-side
        print("🎯 New weekly challenge: \(challenge.title)")
    }
    
    // MARK: - Challenge Status
    
    func getProgressPercentage() -> Double {
        guard let challenge = currentChallenge else { return 0.0 }
        
        let currentProgress = userProgress[challenge.type.rawValue] ?? 0
        return min(Double(currentProgress) / Double(challenge.target), 1.0)
    }
    
    func getDaysRemaining() -> Int {
        guard let challenge = currentChallenge else { return 0 }
        
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.day], from: now, to: challenge.endDate)
        return max(components.day ?? 0, 0)
    }
    
    func isChallengeCompleted() -> Bool {
        guard let challenge = currentChallenge else { return false }
        
        let currentProgress = userProgress[challenge.type.rawValue] ?? 0
        return currentProgress >= challenge.target
    }
}
