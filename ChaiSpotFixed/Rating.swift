import Foundation
import FirebaseFirestoreSwift

struct Rating: Identifiable, Codable {
    @DocumentID var id: String?
    var spotId: String
    var userId: String
    var username: String?  // Optional display name for the reviewer
    var value: Int         // Rating value, e.g., 1–5
    var comment: String?
    @ServerTimestamp var timestamp: Date?
    var likes: Int?
    var dislikes: Int?
}
