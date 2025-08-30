import Foundation
import SwiftUI
import Firebase
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore

struct FriendService {

    // ✅ Create user document on first login
    static func createUserDocumentIfNeeded(completion: @escaping (Bool) -> Void) {
        // Check if Firebase is initialized before accessing Auth
        if FirebaseApp.app() == nil {
            print("⚠️ Firebase not initialized")
            completion(false)
            return
        }
        
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
            let fallbackName = (name?.isEmpty == false ? name : nil) ?? (user.email ?? "Anonymous")

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
        // Check if Firebase is initialized before accessing Auth
        if FirebaseApp.app() == nil {
            print("⚠️ Firebase not initialized")
            completion(false)
            return
        }
        
        guard let senderUID = Auth.auth().currentUser?.uid else {
            print("❌ No current user found for friend request")
            completion(false)
            return
        }

        // Prevent users from sending friend requests to themselves
        if senderUID == recipientUID {
            print("❌ Cannot send friend request to yourself")
            completion(false)
            return
        }

        print("🔄 Sending friend request from \(senderUID) to \(recipientUID)")

        let db = Firestore.firestore()
        let timestamp = Timestamp()
        let batch = db.batch()

        // Get sender's profile information
        let senderUserRef = db.collection("users").document(senderUID)
        
        senderUserRef.getDocument { senderDoc, senderError in
            if let senderError = senderError {
                print("❌ Failed to get sender profile: \(senderError.localizedDescription)")
                completion(false)
                return
            }
            
            guard let senderData = senderDoc?.data() else {
                print("❌ Sender profile not found")
                completion(false)
                return
            }
            
            let senderName = senderData["displayName"] as? String ?? "Unknown User"
            let senderEmail = senderData["email"] as? String ?? "unknown@email.com"
            let senderPhotoURL = senderData["photoURL"] as? String ?? ""
            
            // Add to subcollections with sender's profile information
            let incomingRef = db.collection("users").document(recipientUID)
                .collection("incomingFriendRequests").document(senderUID)
            let outgoingRef = db.collection("users").document(senderUID)
                .collection("outgoingFriendRequests").document(recipientUID)

            // Store sender's profile information in the incoming request document
            let incomingRequestData: [String: Any] = [
                "timestamp": timestamp,
                "uid": senderUID,
                "displayName": senderName,
                "email": senderEmail,
                "photoURL": senderPhotoURL
            ]
            
            // Store just timestamp in the outgoing request document (no need for recipient profile)
            let outgoingRequestData: [String: Any] = [
                "timestamp": timestamp
            ]
            
            batch.setData(incomingRequestData, forDocument: incomingRef)
            batch.setData(outgoingRequestData, forDocument: outgoingRef)

            // Update arrays in user documents
            let recipientUserRef = db.collection("users").document(recipientUID)

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
                    print("❌ Failed to send friend request: \(error.localizedDescription)")
                    completion(false)
                } else {
                    print("✅ Friend request sent successfully in Firestore")
                    
                    // Send notification to recipient about new friend request
                    print("📱 Friend request notification would be sent to \(recipientUID) from \(senderName)")
                    
                    completion(true)
                }
            }
        }
    }

    // ✅ Accept Friend Request
    static func acceptFriendRequest(from senderUID: String, completion: @escaping (Bool) -> Void) {
        // Check if Firebase is initialized before accessing Auth
        if FirebaseApp.app() == nil {
            print("⚠️ Firebase not initialized")
            completion(false)
            return
        }
        
        guard let currentUID = Auth.auth().currentUser?.uid else {
            completion(false)
            return
        }

        let db = Firestore.firestore()
        let timestamp = Timestamp()
        let batch = db.batch()

        // Get both users' profile information
        let currentUserRef = db.collection("users").document(currentUID)
        let senderUserRef = db.collection("users").document(senderUID)
        
        // First, get current user's profile
        currentUserRef.getDocument { currentUserDoc, currentUserError in
            if let currentUserError = currentUserError {
                print("❌ Failed to get current user profile: \(currentUserError.localizedDescription)")
                completion(false)
                return
            }
            
            guard let currentUserData = currentUserDoc?.data() else {
                print("❌ Current user profile not found")
                completion(false)
                return
            }
            
            // Then, get sender's profile
            senderUserRef.getDocument { senderUserDoc, senderUserError in
                if let senderUserError = senderUserError {
                    print("❌ Failed to get sender profile: \(senderUserError.localizedDescription)")
                    completion(false)
                    return
                }
                
                guard let senderUserData = senderUserDoc?.data() else {
                    print("❌ Sender profile not found")
                    completion(false)
                    return
                }
                
                let currentUserName = currentUserData["displayName"] as? String ?? "Unknown User"
                let currentUserEmail = currentUserData["email"] as? String ?? "unknown@email.com"
                let currentUserPhotoURL = currentUserData["photoURL"] as? String ?? ""
                
                let senderName = senderUserData["displayName"] as? String ?? "Unknown User"
                let senderEmail = senderUserData["email"] as? String ?? "unknown@email.com"
                let senderPhotoURL = senderUserData["photoURL"] as? String ?? ""
                
                // Add to friends subcollections with profile information
                let currentUserFriendRef = db.collection("users").document(currentUID)
                    .collection("friends").document(senderUID)
                let senderUserFriendRef = db.collection("users").document(senderUID)
                    .collection("friends").document(currentUID)

                // Store sender's profile in current user's friends collection
                let currentUserFriendData: [String: Any] = [
                    "timestamp": timestamp,
                    "uid": senderUID,
                    "displayName": senderName,
                    "email": senderEmail,
                    "photoURL": senderPhotoURL
                ]
                
                // Store current user's profile in sender's friends collection
                let senderUserFriendData: [String: Any] = [
                    "timestamp": timestamp,
                    "uid": currentUID,
                    "displayName": currentUserName,
                    "email": currentUserEmail,
                    "photoURL": currentUserPhotoURL
                ]

                // Remove from requests subcollections
                let incomingRequestRef = db.collection("users").document(currentUID)
                    .collection("incomingFriendRequests").document(senderUID)
                let outgoingRequestRef = db.collection("users").document(senderUID)
                    .collection("outgoingFriendRequests").document(currentUID)

                batch.setData(currentUserFriendData, forDocument: currentUserFriendRef)
                batch.setData(senderUserFriendData, forDocument: senderUserFriendRef)
                batch.deleteDocument(incomingRequestRef)
                batch.deleteDocument(outgoingRequestRef)

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
                        print("❌ Failed to accept friend request: \(error.localizedDescription)")
                        completion(false)
                    } else {
                        print("✅ Friend request accepted successfully")
                        completion(true)
                    }
                }
            }
        }
    }

    // ✅ Reject Friend Request
    static func rejectFriendRequest(from senderUID: String, completion: @escaping (Bool) -> Void) {
        // Check if Firebase is initialized before accessing Auth
        if FirebaseApp.app() == nil {
            print("⚠️ Firebase not initialized")
            completion(false)
            return
        }
        
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

    // ✅ Cancel Outgoing Friend Request
    static func cancelOutgoingFriendRequest(to recipientUID: String, completion: @escaping (Bool) -> Void) {
        // Check if Firebase is initialized before accessing Auth
        if FirebaseApp.app() == nil {
            print("⚠️ Firebase not initialized")
            completion(false)
            return
        }
        
        guard let currentUID = Auth.auth().currentUser?.uid else {
            completion(false)
            return
        }
        
        let db = Firestore.firestore()
        let batch = db.batch()
        
        // Remove from requests subcollections
        let outgoingRequestRef = db.collection("users").document(currentUID)
            .collection("outgoingFriendRequests").document(recipientUID)
        let incomingRequestRef = db.collection("users").document(recipientUID)
            .collection("incomingFriendRequests").document(currentUID)
        
        batch.deleteDocument(outgoingRequestRef)
        batch.deleteDocument(incomingRequestRef)
        
        // Update arrays in user documents
        let currentUserRef = db.collection("users").document(currentUID)
        let recipientUserRef = db.collection("users").document(recipientUID)
        
        batch.updateData([
            "outgoingRequests": FieldValue.arrayRemove([recipientUID])
        ], forDocument: currentUserRef)
        batch.updateData([
            "incomingRequests": FieldValue.arrayRemove([currentUID])
        ], forDocument: recipientUserRef)
        
        batch.commit { error in
            if let error = error {
                print("❌ Failed to cancel outgoing friend request: \(error.localizedDescription)")
                completion(false)
            } else {
                print("✅ Outgoing friend request canceled successfully")
                completion(true)
            }
        }
    }

    // ✅ Get all friends' ratings for a given chai spot
    static func getFriendsRatings(forSpotId spotId: String, completion: @escaping ([Rating]) -> Void) {
        // Check if Firebase is initialized before accessing Auth
        if FirebaseApp.app() == nil {
            print("⚠️ Firebase not initialized")
            completion([])
            return
        }
        
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
        // Check if Firebase is initialized before accessing Auth
        if FirebaseApp.app() == nil {
            print("⚠️ Firebase not initialized")
            completion(nil)
            return
        }
        
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
