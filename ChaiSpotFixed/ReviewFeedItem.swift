import Foundation

struct ReviewFeedItem: Identifiable {
    let id: String
    let spotId: String
    var spotName: String // Made mutable so it can be updated
    var spotAddress: String // Made mutable so it can be updated
    let userId: String
    let username: String
    let rating: Int
    let comment: String?
    let timestamp: Date
    let chaiType: String?
    
    // New rating fields
    let creaminessRating: Int?
    let chaiStrengthRating: Int?
    let flavorNotes: [String]?
    
    // 🎮 NEW: Photo and gamification fields
    let photoURL: String?
    let hasPhoto: Bool
    let gamificationScore: Int
    let isFirstReview: Bool
    let isNewSpot: Bool
    
    // 🎮 NEW: Social reactions field
    let reactions: [String: Int]
} 