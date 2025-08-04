import Foundation

struct ReviewFeedItem: Identifiable {
    let id: String
    let spotId: String
    let spotName: String
    let spotAddress: String
    let userId: String
    let username: String
    let rating: Int
    let comment: String?
    let timestamp: Date
    let chaiType: String?
} 