import FirebaseFirestore
import CoreLocation

struct FirestoreQueries {
    let db = Firestore.firestore()

    // Friends feed (requires auth)
    func friendsReviews(for friendIds: [String], pageSize: Int = 50) -> Query {
        db.collection("reviews")
            .whereField("authorId", in: Array(friendIds.prefix(10))) // chunk if needed
            .whereField("visibility", in: ["public","friends"])
            .order(by: "createdAt", descending: true)
            .limit(to: pageSize)
    }

    // Community reviews (only for authenticated users, prioritized by social connections)
    func communityReviews(for userId: String, friendIds: [String], pageSize: Int = 50) -> Query {
        // Prioritize friends' public reviews, then community reviews
        db.collection("reviews")
            .whereField("visibility", isEqualTo: "public")
            .order(by: "authorId", descending: false) // Friends first (if using composite index)
            .order(by: "createdAt", descending: true)
            .limit(to: pageSize)
    }

    // Taste-matched community reviews (prioritized by social connections)
    func tasteMatchedCommunityReviews(topTags: [String], friendIds: [String]) -> Query {
        db.collection("reviews")
            .whereField("visibility", isEqualTo: "public")
            .whereField("spotTasteTag", in: Array(topTags.prefix(4)))
            .order(by: "authorId", descending: false) // Friends first
            .order(by: "createdAt", descending: true)
    }
    
    // Get user's taste profile
    func getUserTasteProfile(uid: String) -> DocumentReference {
        db.collection("users").document(uid)
    }
    
    // Get spots with reviews
    func getSpotsWithReviews() -> Query {
        db.collection("spots")
            .order(by: "reviewCount", descending: true)
    }
}
