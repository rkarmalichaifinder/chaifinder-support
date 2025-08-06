import Foundation
import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore

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
                    completion(false)
                } else {
                    completion(true)
                }
            }
        }
    }

    // ✅ Send Friend Request using subcollections and arrays
    static func sendFriendRequest(to recipientUID: String, completion: @escaping (Bool) -> Void) {
        guard let senderUID = Auth.auth().currentUser?.uid else {
            completion(false)
            return
        }

        let db = Firestore.firestore()
        let timestamp = Timestamp()
        let batch = db.batch()

        // Add to subcollections
        let incomingRef = db.collection("users").document(recipientUID)
            .collection("incomingFriendRequests").document(senderUID)
        let outgoingRef = db.collection("users").document(senderUID)
            .collection("outgoingFriendRequests").document(recipientUID)

        batch.setData(["timestamp": timestamp], forDocument: incomingRef)
        batch.setData(["timestamp": timestamp], forDocument: outgoingRef)

        // Update arrays in user documents
        let recipientUserRef = db.collection("users").document(recipientUID)
        let senderUserRef = db.collection("users").document(senderUID)

        // Add sender to recipient's incoming requests array
        batch.updateData([
            "incomingRequests": FieldValue.arrayUnion([senderUID])
        ], forDocument: recipientUserRef)

        // Add recipient to sender's outgoing requests array
        batch.updateData([
            "outgoingRequests": FieldValue.arrayUnion([recipientUID])
        ], forDocument: senderUserRef)

        batch.commit { error in
            if let error = error {
                completion(false)
            } else {
                completion(true)
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

        // Add to friends subcollections
        let currentUserFriendRef = db.collection("users").document(currentUID)
            .collection("friends").document(senderUID)
        let senderUserFriendRef = db.collection("users").document(senderUID)
            .collection("friends").document(currentUID)

        // Remove from requests subcollections
        let incomingRequestRef = db.collection("users").document(currentUID)
            .collection("incomingFriendRequests").document(senderUID)
        let outgoingRequestRef = db.collection("users").document(senderUID)
            .collection("outgoingFriendRequests").document(currentUID)

        batch.setData(["timestamp": timestamp], forDocument: currentUserFriendRef)
        batch.setData(["timestamp": timestamp], forDocument: senderUserFriendRef)
        batch.deleteDocument(incomingRequestRef)
        batch.deleteDocument(outgoingRequestRef)

        // Update arrays in user documents
        let currentUserRef = db.collection("users").document(currentUID)
        let senderUserRef = db.collection("users").document(senderUID)

        // Add to friends arrays
        batch.updateData([
            "friends": FieldValue.arrayUnion([senderUID])
        ], forDocument: currentUserRef)
        batch.updateData([
            "friends": FieldValue.arrayUnion([currentUID])
        ], forDocument: senderUserRef)

        // Remove from requests arrays
        batch.updateData([
            "incomingRequests": FieldValue.arrayRemove([senderUID])
        ], forDocument: currentUserRef)
        batch.updateData([
            "outgoingRequests": FieldValue.arrayRemove([currentUID])
        ], forDocument: senderUserRef)

        batch.commit { error in
            if let error = error {
                completion(false)
            } else {
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
        let batch = db.batch()

        // Remove from requests subcollections
        let incomingRequestRef = db.collection("users").document(currentUID)
            .collection("incomingFriendRequests").document(senderUID)
        let outgoingRequestRef = db.collection("users").document(senderUID)
            .collection("outgoingFriendRequests").document(currentUID)

        batch.deleteDocument(incomingRequestRef)
        batch.deleteDocument(outgoingRequestRef)

        // Update arrays in user documents
        let currentUserRef = db.collection("users").document(currentUID)
        let senderUserRef = db.collection("users").document(senderUID)

        // Remove from requests arrays
        batch.updateData([
            "incomingRequests": FieldValue.arrayRemove([senderUID])
        ], forDocument: currentUserRef)
        batch.updateData([
            "outgoingRequests": FieldValue.arrayRemove([currentUID])
        ], forDocument: senderUserRef)

        batch.commit { error in
            if let error = error {
                completion(false)
            } else {
                completion(true)
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
