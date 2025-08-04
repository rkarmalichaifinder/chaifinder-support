import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import FirebaseFirestoreSwift

class FeedViewModel: ObservableObject {
    @Published var reviews: [ReviewFeedItem] = []
    @Published var filteredReviews: [ReviewFeedItem] = []
    @Published var isLoading = false
    @Published var error: String?
    
    private let db = Firestore.firestore()
    
    func loadFeed() {
        isLoading = true
        error = nil
        
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            // If not logged in, load community ratings
            loadCommunityRatings()
            return
        }
        
        // Check if user has friends
        checkUserFriends(currentUserId: currentUserId) { hasFriends in
            if hasFriends {
                // Load friend ratings
                self.loadFriendRatings(currentUserId: currentUserId)
            } else {
                // Load community ratings
                self.loadCommunityRatings()
            }
        }
    }
    
    private func checkUserFriends(currentUserId: String, completion: @escaping (Bool) -> Void) {
        db.collection("users").document(currentUserId).getDocument { snapshot, error in
            if let error = error {
                print("❌ Error checking user friends: \(error.localizedDescription)")
                completion(false)
                return
            }
            
            guard let data = snapshot?.data(),
                  let friends = data["friends"] as? [String] else {
                completion(false)
                return
            }
            
            completion(!friends.isEmpty)
        }
    }
    
    private func loadFriendRatings(currentUserId: String) {
        // For now, fall back to community ratings to avoid complexity
        // TODO: Implement proper friend ratings loading
        print("🔄 Friend ratings not implemented yet, loading community ratings")
        loadCommunityRatings()
    }
    
    private func loadCommunityRatings() {
        print("🔄 Loading community ratings...")
        
        db.collection("ratings")
            .order(by: "timestamp", descending: true)
            .limit(to: 50)
            .getDocuments { snapshot, error in
                DispatchQueue.main.async {
                    self.isLoading = false
                    
                    if let error = error {
                        self.error = error.localizedDescription
                        print("❌ Error loading community ratings: \(error.localizedDescription)")
                        return
                    }
                    
                    guard let documents = snapshot?.documents else {
                        self.reviews = []
                        self.filteredReviews = []
                        return
                    }
                    
                    self.processRatingDocuments(documents)
                }
            }
    }
    

    
    private func processRatingDocuments(_ documents: [QueryDocumentSnapshot]) {
        // This method is now handled by processRatingDocumentsForFeed
        // which updates the state asynchronously
        _ = processRatingDocumentsForFeed(documents)
    }
    
    private func processRatingDocumentsForFeed(_ documents: [QueryDocumentSnapshot]) -> [ReviewFeedItem] {
        let group = DispatchGroup()
        var feedItems: [ReviewFeedItem] = []
        var processedCount = 0
        
        for document in documents {
            guard let data = document.data() as? [String: Any],
                  let spotId = data["spotId"] as? String,
                  let userId = data["userId"] as? String,
                  let value = data["value"] as? Int else {
                continue
            }
            
            let username = data["username"] as? String ?? "Anonymous"
            let comment = data["comment"] as? String
            let timestamp = data["timestamp"] as? Timestamp
            let chaiType = data["chaiType"] as? String
            
            group.enter()
            
            // Load spot information from chaiFinder collection
            db.collection("chaiFinder").document(spotId).getDocument { snapshot, error in
                defer { group.leave() }
                
                let spotName: String
                let spotAddress: String
                
                if let spotData = snapshot?.data(),
                   let name = spotData["name"] as? String,
                   let address = spotData["address"] as? String {
                    spotName = name
                    spotAddress = address
                } else {
                    spotName = "Unknown Spot"
                    spotAddress = "Unknown Address"
                }
                
                let feedItem = ReviewFeedItem(
                    id: document.documentID,
                    spotId: spotId,
                    spotName: spotName,
                    spotAddress: spotAddress,
                    userId: userId,
                    username: username,
                    rating: value,
                    comment: comment,
                    timestamp: timestamp?.dateValue() ?? Date(),
                    chaiType: chaiType
                )
                
                feedItems.append(feedItem)
                processedCount += 1
                
                print("📄 Processed rating \(processedCount)/\(documents.count): \(spotName) - \(username)")
            }
        }
        
        group.notify(queue: .main) {
            // Sort by timestamp (newest first)
            self.reviews = feedItems.sorted { $0.timestamp > $1.timestamp }
            self.filteredReviews = self.reviews
            self.isLoading = false
            
            print("✅ Loaded \(self.reviews.count) ratings with spot information")
        }
        
        // Return empty array for now, will be updated in group.notify
        return []
    }
    
    func filterReviews(_ searchText: String) {
        if searchText.isEmpty {
            filteredReviews = reviews
        } else {
            filteredReviews = reviews.filter { review in
                review.spotName.localizedCaseInsensitiveContains(searchText) ||
                review.username.localizedCaseInsensitiveContains(searchText) ||
                (review.comment?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (review.chaiType?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
    }
} 