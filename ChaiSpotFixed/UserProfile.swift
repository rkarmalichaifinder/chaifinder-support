import Foundation
import FirebaseFirestore

struct UserProfile: Identifiable, Codable, Equatable {
    var id: String?
    var uid: String
    var displayName: String
    var email: String
    var photoURL: String?
    var friends: [String]? = []
    var incomingRequests: [String]? = []  // ✅ Friend requests received
    var outgoingRequests: [String]? = []  // ✅ Friend requests sent
    var bio: String? = nil                // ✅ Optional user bio
    var hasTasteSetup: Bool = false       // ✅ Whether user has completed taste onboarding
    var tasteVector: [Int]? = nil         // ✅ [creaminess, strength] scores 1-5
    var topTasteTags: [String]? = nil     // ✅ Favorite flavor notes
    var privacyDefaults: PrivacyDefaults? = nil // ✅ Default privacy settings
    
    // 🎮 NEW GAMIFICATION FIELDS
    var badges: [String] = []                    // ✅ Earned badges
    var currentStreak: Int = 0                   // ✅ Current daily review streak
    var longestStreak: Int = 0                   // ✅ Longest streak achieved
    var lastReviewDate: Date?                    // ✅ Date of last review for streak tracking

    var totalReviews: Int = 0                    // ✅ Total number of reviews
    var spotsVisited: Int = 0                    // ✅ Unique chai spots visited
    var challengeProgress: [String: Int] = [:]   // ✅ Progress on monthly challenges
    var achievements: [String: Date] = [:]       // ✅ Achievement unlock dates
    var totalScore: Int = 0                      // ✅ Overall gamification score
    
    init(id: String? = nil, uid: String, displayName: String, email: String, photoURL: String? = nil, friends: [String]? = [], incomingRequests: [String]? = [], outgoingRequests: [String]? = [], bio: String? = nil, hasTasteSetup: Bool = false, tasteVector: [Int]? = nil, topTasteTags: [String]? = nil, privacyDefaults: PrivacyDefaults? = nil, badges: [String] = [], currentStreak: Int = 0, longestStreak: Int = 0, lastReviewDate: Date? = nil, chaiPersonality: String? = nil, totalReviews: Int = 0, spotsVisited: Int = 0, challengeProgress: [String: Int] = [:], achievements: [String: Date] = [:], totalScore: Int = 0) {
        self.id = id
        self.uid = uid
        self.displayName = displayName
        self.email = email
        self.photoURL = photoURL
        self.friends = friends
        self.incomingRequests = incomingRequests
        self.outgoingRequests = outgoingRequests
        self.bio = bio
        self.hasTasteSetup = hasTasteSetup
        self.tasteVector = tasteVector
        self.topTasteTags = topTasteTags
        self.privacyDefaults = privacyDefaults
        self.badges = badges
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.lastReviewDate = lastReviewDate

        self.totalReviews = totalReviews
        self.spotsVisited = spotsVisited
        self.challengeProgress = challengeProgress
        self.achievements = achievements
        self.totalScore = totalScore
    }
}

// 🎖️ NEW: Badge and Achievement Models
struct Badge: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var description: String
    var iconName: String
    var category: BadgeCategory
    var requirement: Int
    var rarity: BadgeRarity
    var unlockedAt: Date?
    
    enum BadgeCategory: String, Codable, CaseIterable {
        case firstSteps = "First Steps"
        case exploration = "Exploration"
        case social = "Social"
        case mastery = "Mastery"
        case seasonal = "Seasonal"
    }
    
    enum BadgeRarity: String, Codable, CaseIterable {
        case common = "Common"
        case rare = "Rare"
        case epic = "Epic"
        case legendary = "Legendary"
        
        var color: String {
            switch self {
            case .common: return "gray"
            case .rare: return "blue"
            case .epic: return "purple"
            case .legendary: return "orange"
            }
        }
    }
}

struct Achievement: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var description: String
    var points: Int
    var unlockedAt: Date?
    var isUnlocked: Bool {
        return unlockedAt != nil
    }
}



struct PrivacyDefaults: Codable, Equatable {
    var reviewsDefaultVisibility: String = "public"  // "public", "friends", "private"
    var allowFriendsSeeAll: Bool = true
}
