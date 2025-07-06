import Foundation
import Firebase
import FirebaseFirestore
import FirebaseFirestoreSwift

struct FriendService {

    // ✅ Create user document on first login
    static func createUserDocumentIfNeeded(completion: @escaping (Bool) -> Void) {
        guard let user = Auth.auth().currentUser else {
            completion(false)
            return
        }

        let db = Firestore.firestore()
        let usersRef = db.collection("users").document(user.uid)

        usersRef.getDocument { docSnapshot, error in
            if let doc = docSnapshot, doc.exists {
                print("✅ User document already exists.")
                completion(true)
                return
            }

            let name = user.displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
            let fallbackName = name?.isEmpty == false ? name! : (user.email ?? "Anonymous")

            var newUserData: [String: Any] = [
                "uid": user.uid,
                "displayName": fallbackName,
                "email": user.email ?? "",
                "bio": ""
            ]

            if let url = user.photoURL?.absoluteString, !url.isEmpty {
                newUserData["photoURL"] = url
            }

            usersRef.setData(newUserData) { error in
                if let error = error {
                    print("❌ Failed to create user document: \(error.localizedDescription)")
                    completion(false)
                } else {
                    print("✅ Created user document for \(user.uid)")
                    completion(true)
                }
            }
        }
    }

    // ✅ Send Friend Request using subcollections
    static func sendFriendRequest(to recipientUID: String, completion: @escaping (Bool) -> Void) {
        guard let senderUID = Auth.auth().currentUser?.uid else {
            completion(false)
            return
        }

        let db = Firestore.firestore()
        let timestamp = Timestamp()

        let incomingRef = db.collection("users").document(recipientUID)
            .collection("incomingFriendRequests").document(senderUID)

        let outgoingRef = db.collection("users").document(senderUID)
            .collection("outgoingFriendRequests").document(recipientUID)

        incomingRef.setData(["timestamp": timestamp]) { error in
            if let error = error {
                print("❌ Failed to add to recipient's incomingFriendRequests: \(error.localizedDescription)")
                completion(false)
                return
            }

            outgoingRef.setData(["timestamp": timestamp]) { error in
                if let error = error {
                    print("❌ Failed to add to sender's outgoingFriendRequests: \(error.localizedDescription)")
                    completion(false)
                } else {
                    print("✅ Friend request sent!")
                    completion(true)
                }
            }
        }
    }

    // ✅ Accept Friend Request
    static func acceptFriendRequest(from senderUID: String, completion: @escaping (Bool) -> Void) {
        guard let currentUID = Auth.auth().currentUser?.uid else {
            completion(false)
            return
        }

        let db = Firestore.firestore()
        let timestamp = Timestamp()
        let batch = db.batch()

        let currentUserFriendRef = db.collection("users").document(currentUID)
            .collection("friends").document(senderUID)
        let senderUserFriendRef = db.collection("users").document(senderUID)
            .collection("friends").document(currentUID)

        let incomingRequestRef = db.collection("users").document(currentUID)
            .collection("incomingFriendRequests").document(senderUID)
        let outgoingRequestRef = db.collection("users").document(senderUID)
            .collection("outgoingFriendRequests").document(currentUID)

        batch.setData(["timestamp": timestamp], forDocument: currentUserFriendRef)
        batch.setData(["timestamp": timestamp], forDocument: senderUserFriendRef)
        batch.deleteDocument(incomingRequestRef)
        batch.deleteDocument(outgoingRequestRef)

        batch.commit { error in
            if let error = error {
                print("❌ Error accepting friend request: \(error.localizedDescription)")
                completion(false)
            } else {
                print("✅ Friend request accepted!")
                completion(true)
            }
        }
    }

    // ✅ Reject Friend Request
    static func rejectFriendRequest(from senderUID: String, completion: @escaping (Bool) -> Void) {
        guard let currentUID = Auth.auth().currentUser?.uid else {
            completion(false)
            return
        }

        let db = Firestore.firestore()
        let incomingRequestRef = db.collection("users").document(currentUID)
            .collection("incomingFriendRequests").document(senderUID)
        let outgoingRequestRef = db.collection("users").document(senderUID)
            .collection("outgoingFriendRequests").document(currentUID)

        incomingRequestRef.delete { error in
            if let error = error {
                print("❌ Failed to delete incoming request: \(error.localizedDescription)")
                completion(false)
                return
            }

            outgoingRequestRef.delete { error in
                if let error = error {
                    print("❌ Failed to delete outgoing request: \(error.localizedDescription)")
                    completion(false)
                } else {
                    print("✅ Friend request rejected.")
                    completion(true)
                }
            }
        }
    }

    // ✅ Get all friends' ratings for a given chai spot
    static func getFriendsRatings(forSpotId spotId: String, completion: @escaping ([Rating]) -> Void) {
        guard let currentUID = Auth.auth().currentUser?.uid else {
            completion([])
            return
        }

        let db = Firestore.firestore()
        let friendsRef = db.collection("users").document(currentUID).collection("friends")

        friendsRef.getDocuments { snapshot, error in
            guard let documents = snapshot?.documents else {
                print("❌ Failed to fetch friends list: \(error?.localizedDescription ?? "Unknown error")")
                completion([])
                return
            }

            let friendUIDs = documents.map { $0.documentID }

            if friendUIDs.isEmpty {
                completion([])
                return
            }

            db.collection("ratings")
                .whereField("spotId", isEqualTo: spotId)
                .whereField("userId", in: friendUIDs)
                .getDocuments { snapshot, error in
                    guard let docs = snapshot?.documents else {
                        print("❌ Failed to fetch friends' ratings: \(error?.localizedDescription ?? "Unknown error")")
                        completion([])
                        return
                    }

                    let ratings = docs.compactMap { try? $0.data(as: Rating.self) }
                    completion(ratings)
                }
        }
    }

    // ✅ Get the current user's rating for a chai spot
    static func getMyRating(forSpotId spotId: String, completion: @escaping (Rating?) -> Void) {
        guard let currentUID = Auth.auth().currentUser?.uid else {
            completion(nil)
            return
        }

        Firestore.firestore().collection("ratings")
            .whereField("spotId", isEqualTo: spotId)
            .whereField("userId", isEqualTo: currentUID)
            .getDocuments { snapshot, error in
                guard let doc = snapshot?.documents.first else {
                    completion(nil)
                    return
                }

                let rating = try? doc.data(as: Rating.self)
                completion(rating)
            }
    }
}
