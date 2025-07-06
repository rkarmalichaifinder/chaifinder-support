import Foundation
import FirebaseFirestoreSwift

struct Rating: Identifiable, Codable {
    @DocumentID var id: String?
    var spotId: String
    var userId: String
    var username: String?  // 👈 Add this line
    var value: Int
    var comment: String?
    @ServerTimestamp var timestamp: Date?
    var likes: Int?
    var dislikes: Int?
    var chaiType: String? // e.g. "Karak", "Masala", etc.
}
