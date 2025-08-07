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
    
    init(id: String? = nil, uid: String, displayName: String, email: String, photoURL: String? = nil, friends: [String]? = [], incomingRequests: [String]? = [], outgoingRequests: [String]? = [], bio: String? = nil) {
        self.id = id
        self.uid = uid
        self.displayName = displayName
        self.email = email
        self.photoURL = photoURL
        self.friends = friends
        self.incomingRequests = incomingRequests
        self.outgoingRequests = outgoingRequests
        self.bio = bio
    }
}
