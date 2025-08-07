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
    private var hasLoadedData = false
    
    func loadFeed() {
        // Prevent multiple simultaneous loads
        if isLoading && hasLoadedData {
            return
        }
        
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
                DispatchQueue.main.async {
                    if hasFriends {
                        // Load friend ratings
                        self.loadFriendRatings(currentUserId: currentUserId)
                    } else {
                        // No friends, switch to community
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
        hasLoadedData = false
        loadFeed()
    }
    
    func clearCache() {
        spotDetailsCache.removeAll()
        loadingSpots.removeAll()
        hasLoadedData = false
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
            DispatchQueue.main.async {
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
                            self.hasLoadedData = true
                        }
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
                    self.hasLoadedData = true
                }
            }
    }
    
    private func processRatingDocuments(_ documents: [QueryDocumentSnapshot]) {
        // Process documents on background queue to avoid blocking main thread
        DispatchQueue.global(qos: .userInitiated).async {
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
                
                return feedItem
            }
            
            // Update UI on main thread
            DispatchQueue.main.async {
                self.reviews = feedItems.sorted { $0.timestamp > $1.timestamp }
                self.filteredReviews = self.reviews
                
                // Load spot details asynchronously after initial load
                for feedItem in feedItems {
                    self.loadSpotDetails(for: feedItem.spotId) { spotName, spotAddress in
                        DispatchQueue.main.async {
                            if let index = self.reviews.firstIndex(where: { $0.id == feedItem.id }) {
                                self.reviews[index].spotName = spotName
                                self.reviews[index].spotAddress = spotAddress
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func processFriendRatingDocuments(_ documents: [QueryDocumentSnapshot]) {
        // Process documents on background queue to avoid blocking main thread
        DispatchQueue.global(qos: .userInitiated).async {
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
                
                return feedItem
            }
            
            // Update UI on main thread
            DispatchQueue.main.async {
                self.reviews = feedItems.sorted { $0.timestamp > $1.timestamp }
                self.filteredReviews = self.reviews
                
                // Load spot details asynchronously after initial load
                for feedItem in feedItems {
                    self.loadSpotDetails(for: feedItem.spotId) { spotName, spotAddress in
                        DispatchQueue.main.async {
                            if let index = self.reviews.firstIndex(where: { $0.id == feedItem.id }) {
                                self.reviews[index].spotName = spotName
                                self.reviews[index].spotAddress = spotAddress
                            }
                        }
                    }
                }
            }
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