import SwiftUI
import Firebase
import FirebaseCore
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
    
    private lazy var db: Firestore = {
        // Only create Firestore instance when actually needed
        // Firebase should be configured by SessionStore before this is called
        return Firestore.firestore()
    }()
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
        
        // Check if Firebase is initialized before accessing Auth
        if FirebaseApp.app() == nil {
            // Firebase not initialized, load community ratings
            currentFeedType = .community
            loadCommunityRatings()
            return
        }
        
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            // If not logged in, load community ratings
            currentFeedType = .community
            loadCommunityRatings()
            return
        }
        
        switch currentFeedType {
        case .friends:
            // Always attempt to load friend ratings, let the function handle no friends case
            loadFriendRatings(currentUserId: currentUserId)
        case .community:
            loadCommunityRatings()
        }
    }
    
    func switchFeedType(to type: FeedType) {
        currentFeedType = type
        hasLoadedData = false
        isLoading = true
        error = nil
        reviews = []
        filteredReviews = []
        
        // Check if Firebase is initialized before accessing Auth
        if FirebaseApp.app() == nil {
            // Firebase not initialized, load community ratings
            loadCommunityRatings()
            return
        }
        
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            // If not logged in, load community ratings
            loadCommunityRatings()
            return
        }
        
        switch type {
        case .friends:
            // Load friend ratings directly without checking if user has friends
            loadFriendRatingsDirectly(currentUserId: currentUserId)
        case .community:
            loadCommunityRatings()
        }
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
                    self.isLoading = false
                    self.reviews = []
                    self.filteredReviews = []
                    self.error = "Unable to load friends list. Please check your connection."
                    return
                }
                
                guard let data = snapshot?.data(),
                      let friends = data["friends"] as? [String],
                      !friends.isEmpty else {
                    self.isLoading = false
                    self.reviews = []
                    self.filteredReviews = []
                    self.error = "You don't have any friends yet. Add friends to see their reviews here!"
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
                                self.reviews = []
                                self.filteredReviews = []
                                self.error = "Unable to load friend reviews. Please try again."
                                return
                            }
                            
                            guard let documents = snapshot?.documents else {
                                self.reviews = []
                                self.filteredReviews = []
                                self.error = "Your friends haven't posted any reviews yet."
                                return
                            }
                            
                            if documents.isEmpty {
                                self.reviews = []
                                self.filteredReviews = []
                                self.error = "Your friends haven't posted any reviews yet."
                                return
                            }
                            
                            self.processFriendRatingDocuments(documents)
                            self.hasLoadedData = true
                        }
                    }
            }
        }
    }
    
    private func loadFriendRatingsDirectly(currentUserId: String) {
        // Get user's friends list
        db.collection("users").document(currentUserId).getDocument { snapshot, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.isLoading = false
                    self.reviews = []
                    self.filteredReviews = []
                    self.error = "Failed to load friends"
                    return
                }
                
                guard let data = snapshot?.data(),
                      let friends = data["friends"] as? [String] else {
                    self.isLoading = false
                    self.reviews = []
                    self.filteredReviews = []
                    self.error = "No friends found"
                    return
                }
                
                if friends.isEmpty {
                    self.isLoading = false
                    self.reviews = []
                    self.filteredReviews = []
                    self.error = "No friends found"
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
                                self.reviews = []
                                self.filteredReviews = []
                                self.error = "Failed to load friend ratings"
                                return
                            }
                            
                            guard let documents = snapshot?.documents else {
                                self.reviews = []
                                self.filteredReviews = []
                                self.error = "No friend ratings found"
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
                            // Update both reviews and filteredReviews arrays
                            if let index = self.reviews.firstIndex(where: { $0.id == feedItem.id }) {
                                self.reviews[index].spotName = spotName
                                self.reviews[index].spotAddress = spotAddress
                                
                                // Also update filteredReviews if this item is still in the filtered list
                                if let filteredIndex = self.filteredReviews.firstIndex(where: { $0.id == feedItem.id }) {
                                    self.filteredReviews[filteredIndex].spotName = spotName
                                    self.filteredReviews[filteredIndex].spotAddress = spotAddress
                                }
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
                            // Update both reviews and filteredReviews arrays
                            if let index = self.reviews.firstIndex(where: { $0.id == feedItem.id }) {
                                self.reviews[index].spotName = spotName
                                self.reviews[index].spotAddress = spotAddress
                                
                                // Also update filteredReviews if this item is still in the filtered list
                                if let filteredIndex = self.filteredReviews.firstIndex(where: { $0.id == feedItem.id }) {
                                    self.filteredReviews[filteredIndex].spotName = spotName
                                    self.filteredReviews[filteredIndex].spotAddress = spotAddress
                                }
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
                        
                        // Provide a more user-friendly fallback name
                        let fallbackName = "Chai Spot"
                        let fallbackAddress = "Location details unavailable"
                        self.spotDetailsCache[spotId] = (fallbackName, fallbackAddress)
                        completion(fallbackName, fallbackAddress)
                        return
                    }
                    
                    guard let data = snapshot?.data(),
                          let name = data["name"] as? String,
                          let address = data["address"] as? String else {
                        // Provide a more user-friendly fallback name
                        let fallbackName = "Chai Spot"
                        let fallbackAddress = "Location details unavailable"
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
            let searchLower = searchText.lowercased()
            filteredReviews = reviews.filter { review in
                // Search through all relevant fields
                review.spotName.localizedCaseInsensitiveContains(searchText) ||
                review.spotAddress.localizedCaseInsensitiveContains(searchText) ||
                review.username.localizedCaseInsensitiveContains(searchText) ||
                (review.comment?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (review.chaiType?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                // Also search for partial matches in comments
                (review.comment?.lowercased().contains(searchLower) ?? false) ||
                // Search for rating numbers
                String(review.rating).contains(searchText)
            }
        }
    }
} 