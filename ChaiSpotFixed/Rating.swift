import Foundation
import FirebaseFirestore

struct Rating: Identifiable, Codable {
    var id: String?
    var spotId: String
    var userId: String
    var username: String?  // Optional display name for the reviewer
    var spotName: String?  // Name of the spot being rated
    var value: Int         // Rating value, e.g., 1–5
    var comment: String?
    var timestamp: Date?
    var likes: Int?
    var dislikes: Int?
    
    // New rating fields
    var creaminessRating: Int?
    var chaiStrengthRating: Int?
    var flavorNotes: [String]?
    var chaiType: String?
}
