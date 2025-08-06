import Foundation
import FirebaseFirestore

struct UserProfile: Identifiable, Codable {
    @DocumentID var id: String?
    var uid: String
    var displayName: String
    var email: String
    var photoURL: String?
    var friends: [String]? = []
    var incomingRequests: [String]? = []  // ✅ Friend requests received
    var outgoingRequests: [String]? = []  // ✅ Friend requests sent
    var bio: String? = nil                // ✅ Optional user bio
}
