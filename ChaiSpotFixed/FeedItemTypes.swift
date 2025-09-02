import Foundation
import FirebaseFirestore

// MARK: - Feed Item Types
enum FeedItemType: String, CaseIterable, Codable {
    case review = "review"
    case newUser = "newUser"
    case newSpot = "newSpot"
    case achievement = "achievement"
    case friendActivity = "friendActivity"
    case weeklyChallenge = "weeklyChallenge"
    case weeklyRanking = "weeklyRanking"
    
    var displayName: String {
        switch self {
        case .review: return "Review"
        case .newUser: return "New User"
        case .newSpot: return "New Spot"
        case .achievement: return "Achievement"
        case .friendActivity: return "Friend Activity"
        case .weeklyChallenge: return "Weekly Challenge"
        case .weeklyRanking: return "Weekly Ranking"
        }
    }
    
    var icon: String {
        switch self {
        case .review: return "star.fill"
        case .newUser: return "person.badge.plus"
        case .newSpot: return "mappin.circle.fill"
        case .achievement: return "trophy.fill"
        case .friendActivity: return "person.2.fill"
        case .weeklyChallenge: return "flame.fill"
        case .weeklyRanking: return "trophy.circle.fill"
        }
    }
}

// MARK: - Base Feed Item Protocol
protocol FeedItem: Identifiable {
    var id: String { get }
    var type: FeedItemType { get }
    var timestamp: Date { get }
    var userId: String { get }
    var username: String { get }
    var isRead: Bool { get set }
}

// MARK: - Review Feed Item (existing)
struct ReviewFeedItem: FeedItem {
    let id: String
    let type: FeedItemType = .review
    let spotId: String
    var spotName: String
    var spotAddress: String
    let userId: String
    let username: String
    let rating: Int
    let comment: String?
    let timestamp: Date
    let chaiType: String?
    let creaminessRating: Int?
    let chaiStrengthRating: Int?
    let flavorNotes: [String]?
    let photoURL: String?
    let likes: Int
    let dislikes: Int
    var isRead: Bool = false
    
    // Additional fields for enhanced functionality
    let visibility: String
    let deleted: Bool
    let updatedAt: Timestamp?
    
    // 🎮 NEW: Photo and gamification fields (for compatibility with ReviewCardView)
    var hasPhoto: Bool { photoURL != nil && !photoURL!.isEmpty }
    var gamificationScore: Int { 0 } // Default value, can be enhanced later
    var isFirstReview: Bool { false } // Default value, can be enhanced later
    var isNewSpot: Bool { false } // Default value, can be enhanced later
    var reactions: [String: Int] { [:] } // Default empty reactions
    
    // MARK: - Computed Properties for Enhanced Search
    
    /// Extracts city name from the address field
    var cityName: String {
        let addressComponents = spotAddress.components(separatedBy: ",")
        if addressComponents.count >= 2 {
            // Usually city is the second-to-last component before state/zip
            let cityComponent = addressComponents[addressComponents.count - 2].trimmingCharacters(in: .whitespaces)
            return cityComponent
        }
        return spotAddress
    }
    
    /// Extracts neighborhood/area from the address field
    var neighborhood: String {
        let addressComponents = spotAddress.components(separatedBy: ",")
        if addressComponents.count >= 3 {
            // Neighborhood might be in the first component after street address
            let neighborhoodComponent = addressComponents[1].trimmingCharacters(in: .whitespaces)
            return neighborhoodComponent
        }
        return ""
    }
    
    /// Extracts state from the address field
    var state: String {
        let addressComponents = spotAddress.components(separatedBy: ",")
        if addressComponents.count >= 2 {
            // State is usually the last component
            let stateComponent = addressComponents.last?.trimmingCharacters(in: .whitespaces) ?? ""
            return stateComponent
        }
        return ""
    }
    
    /// Creates a searchable text that includes all relevant location information
    var searchableLocationText: String {
        var searchText = spotName
        searchText += " " + spotAddress
        searchText += " " + cityName
        searchText += " " + neighborhood
        searchText += " " + state
        return searchText.lowercased()
    }
    
    /// Creates a searchable text that includes all review content
    var searchableReviewText: String {
        var searchText = username
        if let comment = comment {
            searchText += " " + comment
        }
        if let chaiType = chaiType {
            searchText += " " + chaiType
        }
        if let flavorNotes = flavorNotes {
            searchText += " " + flavorNotes.joined(separator: " ")
        }
        return searchText.lowercased()
    }
}

// MARK: - New User Feed Item
struct NewUserFeedItem: FeedItem {
    let id: String
    let type: FeedItemType = .newUser
    let userId: String
    let username: String
    let timestamp: Date
    let photoURL: String?
    let bio: String?
    var isRead: Bool = false
}

// MARK: - New Spot Feed Item
struct NewSpotFeedItem: FeedItem {
    let id: String
    let type: FeedItemType = .newSpot
    let spotId: String
    let spotName: String
    let spotAddress: String
    let userId: String
    let username: String
    let timestamp: Date
    let chaiTypes: [String]
    let latitude: Double
    let longitude: Double
    var isRead: Bool = false
}

// MARK: - Achievement Feed Item
struct AchievementFeedItem: FeedItem {
    let id: String
    let type: FeedItemType = .achievement
    let userId: String
    let username: String
    let timestamp: Date
    let achievementName: String
    let achievementDescription: String
    let achievementIcon: String
    let pointsEarned: Int
    var isRead: Bool = false
}

// MARK: - Friend Activity Feed Item
struct FriendActivityFeedItem: FeedItem {
    let id: String
    let type: FeedItemType = .friendActivity
    let userId: String
    let username: String
    let timestamp: Date
    let activityType: String // "joined", "added_spot", "earned_achievement", etc.
    let activityDescription: String
    let relatedSpotId: String?
    let relatedSpotName: String?
    var isRead: Bool = false
}

// MARK: - Weekly Challenge Feed Item
struct WeeklyChallengeFeedItem: FeedItem {
    let id: String
    let type: FeedItemType = .weeklyChallenge
    let userId: String
    let username: String
    let timestamp: Date
    let challengeName: String
    let challengeDescription: String
    let progress: Int
    let target: Int
    let reward: String
    var isRead: Bool = false
}

// MARK: - Weekly Ranking Feed Item
struct WeeklyRankingFeedItem: FeedItem {
    let id: String
    let type: FeedItemType = .weeklyRanking
    let userId: String
    let username: String
    let timestamp: Date
    let rank: Int
    let totalUsers: Int
    let score: Int
    let previousRank: Int?
    let rankChange: Int?
    var isRead: Bool = false
}

// MARK: - Feed Item Factory
struct FeedItemFactory {
    static func createFeedItem(from data: [String: Any], documentId: String) -> FeedItem? {
        guard let typeString = data["type"] as? String,
              let type = FeedItemType(rawValue: typeString) else {
            return nil
        }
        
        switch type {
        case .review:
            return createReviewFeedItem(from: data, documentId: documentId)
        case .newUser:
            return createNewUserFeedItem(from: data, documentId: documentId)
        case .newSpot:
            return createNewSpotFeedItem(from: data, documentId: documentId)
        case .achievement:
            return createAchievementFeedItem(from: data, documentId: documentId)
        case .friendActivity:
            return createFriendActivityFeedItem(from: data, documentId: documentId)
        case .weeklyChallenge:
            return createWeeklyChallengeFeedItem(from: data, documentId: documentId)
        case .weeklyRanking:
            return createWeeklyRankingFeedItem(from: data, documentId: documentId)
        }
    }
    
    private static func createReviewFeedItem(from data: [String: Any], documentId: String) -> ReviewFeedItem? {
        guard let userId = data["userId"] as? String,
              let username = data["username"] as? String,
              let timestamp = data["timestamp"] as? Timestamp else {
            return nil
        }
        
        return ReviewFeedItem(
            id: documentId,
            spotId: data["spotId"] as? String ?? "",
            spotName: data["spotName"] as? String ?? "",
            spotAddress: data["spotAddress"] as? String ?? "",
            userId: userId,
            username: username,
            rating: data["value"] as? Int ?? 0,
            comment: data["comment"] as? String,
            timestamp: timestamp.dateValue(),
            chaiType: data["chaiType"] as? String,
            creaminessRating: data["creaminessRating"] as? Int,
            chaiStrengthRating: data["chaiStrengthRating"] as? Int,
            flavorNotes: data["flavorNotes"] as? [String],
            photoURL: data["photoURL"] as? String,
            likes: data["likes"] as? Int ?? 0,
            dislikes: data["dislikes"] as? Int ?? 0,
            isRead: false,
            visibility: data["visibility"] as? String ?? "public",
            deleted: data["deleted"] as? Bool ?? false,
            updatedAt: data["updatedAt"] as? Timestamp
        )
    }
    
    private static func createNewUserFeedItem(from data: [String: Any], documentId: String) -> NewUserFeedItem? {
        guard let userId = data["userId"] as? String,
              let username = data["username"] as? String,
              let timestamp = data["timestamp"] as? Timestamp else {
            return nil
        }
        
        return NewUserFeedItem(
            id: documentId,
            userId: userId,
            username: username,
            timestamp: timestamp.dateValue(),
            photoURL: data["photoURL"] as? String,
            bio: data["bio"] as? String
        )
    }
    
    private static func createNewSpotFeedItem(from data: [String: Any], documentId: String) -> NewSpotFeedItem? {
        guard let spotId = data["spotId"] as? String,
              let spotName = data["spotName"] as? String,
              let userId = data["userId"] as? String,
              let username = data["username"] as? String,
              let timestamp = data["timestamp"] as? Timestamp else {
            return nil
        }
        
        return NewSpotFeedItem(
            id: documentId,
            spotId: spotId,
            spotName: spotName,
            spotAddress: data["spotAddress"] as? String ?? "",
            userId: userId,
            username: username,
            timestamp: timestamp.dateValue(),
            chaiTypes: data["chaiTypes"] as? [String] ?? [],
            latitude: data["latitude"] as? Double ?? 0.0,
            longitude: data["longitude"] as? Double ?? 0.0
        )
    }
    
    private static func createAchievementFeedItem(from data: [String: Any], documentId: String) -> AchievementFeedItem? {
        guard let userId = data["userId"] as? String,
              let username = data["username"] as? String,
              let timestamp = data["timestamp"] as? Timestamp,
              let achievementName = data["achievementName"] as? String else {
            return nil
        }
        
        return AchievementFeedItem(
            id: documentId,
            userId: userId,
            username: username,
            timestamp: timestamp.dateValue(),
            achievementName: achievementName,
            achievementDescription: data["achievementDescription"] as? String ?? "",
            achievementIcon: data["achievementIcon"] as? String ?? "trophy.fill",
            pointsEarned: data["pointsEarned"] as? Int ?? 0
        )
    }
    
    private static func createFriendActivityFeedItem(from data: [String: Any], documentId: String) -> FriendActivityFeedItem? {
        guard let userId = data["userId"] as? String,
              let username = data["username"] as? String,
              let timestamp = data["timestamp"] as? Timestamp,
              let activityType = data["activityType"] as? String else {
            return nil
        }
        
        return FriendActivityFeedItem(
            id: documentId,
            userId: userId,
            username: username,
            timestamp: timestamp.dateValue(),
            activityType: activityType,
            activityDescription: data["activityDescription"] as? String ?? "",
            relatedSpotId: data["relatedSpotId"] as? String,
            relatedSpotName: data["relatedSpotName"] as? String
        )
    }
    
    private static func createWeeklyChallengeFeedItem(from data: [String: Any], documentId: String) -> WeeklyChallengeFeedItem? {
        guard let userId = data["userId"] as? String,
              let username = data["username"] as? String,
              let timestamp = data["timestamp"] as? Timestamp,
              let challengeName = data["challengeName"] as? String else {
            return nil
        }
        
        return WeeklyChallengeFeedItem(
            id: documentId,
            userId: userId,
            username: username,
            timestamp: timestamp.dateValue(),
            challengeName: challengeName,
            challengeDescription: data["challengeDescription"] as? String ?? "",
            progress: data["progress"] as? Int ?? 0,
            target: data["target"] as? Int ?? 0,
            reward: data["reward"] as? String ?? ""
        )
    }
    
    private static func createWeeklyRankingFeedItem(from data: [String: Any], documentId: String) -> WeeklyRankingFeedItem? {
        guard let userId = data["userId"] as? String,
              let username = data["username"] as? String,
              let timestamp = data["timestamp"] as? Timestamp,
              let rank = data["rank"] as? Int,
              let totalUsers = data["totalUsers"] as? Int,
              let score = data["score"] as? Int else {
            return nil
        }
        
        return WeeklyRankingFeedItem(
            id: documentId,
            userId: userId,
            username: username,
            timestamp: timestamp.dateValue(),
            rank: rank,
            totalUsers: totalUsers,
            score: score,
            previousRank: data["previousRank"] as? Int,
            rankChange: data["rankChange"] as? Int
        )
    }
}
