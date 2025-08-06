import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore

enum FeedType {
    case friends
    case community
}

class FeedViewModel: ObservableObject {
    @Published var reviews: [ReviewFeedItem] = []
    @Published var filteredReviews: [ReviewFeedItem] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var currentFeedType: FeedType = .friends
    
    private let db = Firestore.firestore()
    private var spotDetailsCache: [String: (name: String, address: String)] = [:]
    private var loadingSpots: Set<String> = []
    
    func loadFeed() {
        isLoading = true
        error = nil
        
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            // If not logged in, load community ratings
            currentFeedType = .community
            loadCommunityRatings()
            return
        }
        
        switch currentFeedType {
        case .friends:
            // Check if user has friends
            checkUserFriends(currentUserId: currentUserId) { hasFriends in
                if hasFriends {
                    // Load friend ratings
                    self.loadFriendRatings(currentUserId: currentUserId)
                } else {
                    // No friends, switch to community
                    DispatchQueue.main.async {
                        self.currentFeedType = .community
                        self.loadCommunityRatings()
                    }
                }
            }
        case .community:
            loadCommunityRatings()
        }
    }
    
    func switchFeedType(to type: FeedType) {
        currentFeedType = type
        loadFeed()
    }
    
    func clearCache() {
        spotDetailsCache.removeAll()
        loadingSpots.removeAll()
    }
    
    func handleFirebasePermissionError() {
        // Set a flag to show user-friendly error message
        DispatchQueue.main.async {
            self.error = "Some data may not be available due to permission settings. The app will continue to work with available information."
        }
    }
    
    private func checkUserFriends(currentUserId: String, completion: @escaping (Bool) -> Void) {
        db.collection("users").document(currentUserId).getDocument { snapshot, error in
            if let error = error {
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
        // Get user's friends list
        db.collection("users").document(currentUserId).getDocument { snapshot, error in
            if let error = error {
                self.loadCommunityRatings()
                return
            }
            
            guard let data = snapshot?.data(),
                  let friends = data["friends"] as? [String],
                  !friends.isEmpty else {
                self.loadCommunityRatings()
                return
            }
            
            // Load ratings from friends
            self.db.collection("ratings")
                .whereField("userId", in: friends)
                .order(by: "timestamp", descending: true)
                .limit(to: 20)
                .getDocuments { snapshot, error in
                    DispatchQueue.main.async {
                        self.isLoading = false
                        
                        if let error = error {
                            self.loadCommunityRatings()
                            return
                        }
                        
                        guard let documents = snapshot?.documents else {
                            self.loadCommunityRatings()
                            return
                        }
                        
                        self.processFriendRatingDocuments(documents)
                    }
                }
        }
    }
    
    private func loadCommunityRatings() {
        // Add a timeout to prevent hanging
        let timeoutTimer = Timer.scheduledTimer(withTimeInterval: 8.0, repeats: false) { _ in
            DispatchQueue.main.async {
                if self.isLoading {
                    self.isLoading = false
                    self.reviews = []
                    self.filteredReviews = []
                    self.error = "Loading timeout - please try again"
                }
            }
        }
        
        db.collection("ratings")
            .order(by: "timestamp", descending: true)
            .limit(to: 20) // Reduced from 50 to 20 for faster loading
            .getDocuments { snapshot, error in
                timeoutTimer.invalidate() // Cancel timeout if we get a response
                
                DispatchQueue.main.async {
                    self.isLoading = false
                    
                    if let error = error {
                        self.error = error.localizedDescription
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
        let feedItems = documents.compactMap { document -> ReviewFeedItem? in
            guard let data = document.data() as? [String: Any],
                  let spotId = data["spotId"] as? String,
                  let userId = data["userId"] as? String,
                  let value = data["value"] as? Int else {
                return nil
            }
            
            let username = data["username"] as? String ?? "Anonymous"
            let comment = data["comment"] as? String
            let timestamp = data["timestamp"] as? Timestamp
            let chaiType = data["chaiType"] as? String
            
            // Create initial feed item with placeholder spot info
            let feedItem = ReviewFeedItem(
                id: document.documentID,
                spotId: spotId,
                spotName: "Loading...",
                spotAddress: "Loading...",
                userId: userId,
                username: username,
                rating: value,
                comment: comment,
                timestamp: timestamp?.dateValue() ?? Date(),
                chaiType: chaiType
            )
            
            // Load spot details asynchronously
            loadSpotDetails(for: spotId) { spotName, spotAddress in
                DispatchQueue.main.async {
                    if let index = self.reviews.firstIndex(where: { $0.id == document.documentID }) {
                        self.reviews[index].spotName = spotName
                        self.reviews[index].spotAddress = spotAddress
                    }
                }
            }
            
            return feedItem
        }
        
        // Update immediately without any async operations
        DispatchQueue.main.async {
            self.reviews = feedItems.sorted { $0.timestamp > $1.timestamp }
            self.filteredReviews = self.reviews
            self.isLoading = false
        }
        
        return []
    }
    
    private func processFriendRatingDocuments(_ documents: [QueryDocumentSnapshot]) {
        let feedItems = documents.compactMap { document -> ReviewFeedItem? in
            guard let data = document.data() as? [String: Any],
                  let spotId = data["spotId"] as? String,
                  let userId = data["userId"] as? String,
                  let value = data["value"] as? Int else {
                return nil
            }
            
            let username = data["username"] as? String ?? "Anonymous"
            let comment = data["comment"] as? String
            let timestamp = data["timestamp"] as? Timestamp
            let chaiType = data["chaiType"] as? String
            
            // Create initial feed item with placeholder spot info
            let feedItem = ReviewFeedItem(
                id: document.documentID,
                spotId: spotId,
                spotName: "Loading...",
                spotAddress: "Loading...",
                userId: userId,
                username: username,
                rating: value,
                comment: comment,
                timestamp: timestamp?.dateValue() ?? Date(),
                chaiType: chaiType
            )
            
            // Load spot details asynchronously
            loadSpotDetails(for: spotId) { spotName, spotAddress in
                DispatchQueue.main.async {
                    if let index = self.reviews.firstIndex(where: { $0.id == document.documentID }) {
                        self.reviews[index].spotName = spotName
                        self.reviews[index].spotAddress = spotAddress
                    }
                }
            }
            
            return feedItem
        }
        
        DispatchQueue.main.async {
            self.reviews = feedItems.sorted { $0.timestamp > $1.timestamp }
            self.filteredReviews = self.reviews
            self.isLoading = false
        }
    }
    
    private func loadSpotDetails(for spotId: String, completion: @escaping (String, String) -> Void) {
        // Check cache first
        if let cached = spotDetailsCache[spotId] {
            completion(cached.name, cached.address)
            return
        }
        
        // Prevent duplicate requests
        if loadingSpots.contains(spotId) {
            return
        }
        
        loadingSpots.insert(spotId)
        
        // Add retry logic for permission issues
        func attemptLoad(retryCount: Int = 0) {
            db.collection("chaiFinder").document(spotId).getDocument { snapshot, error in
                DispatchQueue.main.async {
                    self.loadingSpots.remove(spotId)
                    
                    if let error = error {
                        // Retry once for permission issues
                        if retryCount == 0 && error.localizedDescription.contains("permissions") {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                attemptLoad(retryCount: 1)
                            }
                            return
                        }
                        
                        let fallbackName = "Chai Spot #\(spotId.prefix(6))"
                        let fallbackAddress = "Tap to view details"
                        self.spotDetailsCache[spotId] = (fallbackName, fallbackAddress)
                        completion(fallbackName, fallbackAddress)
                        return
                    }
                    
                    guard let data = snapshot?.data(),
                          let name = data["name"] as? String,
                          let address = data["address"] as? String else {
                        let fallbackName = "Chai Spot #\(spotId.prefix(6))"
                        let fallbackAddress = "Tap to view details"
                        self.spotDetailsCache[spotId] = (fallbackName, fallbackAddress)
                        completion(fallbackName, fallbackAddress)
                        return
                    }
                    
                    self.spotDetailsCache[spotId] = (name, address)
                    completion(name, address)
                }
            }
        }
        
        attemptLoad()
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