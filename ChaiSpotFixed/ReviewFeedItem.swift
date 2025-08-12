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
} 