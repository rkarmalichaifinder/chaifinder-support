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
    @Published var initialLoadComplete = false
    
    private lazy var db: Firestore = {
        // Only create Firestore instance when actually needed
        // Firebase should be configured by SessionStore before this is called
        return Firestore.firestore()
    }()
    private var spotDetailsCache: [String: (name: String, address: String)] = [:]
    private var loadingSpots: Set<String> = []
    private var hasLoadedData = false
    
    // Add a method to refresh the feed
    func refreshFeed() {
        print("🔄 refreshFeed() called - clearing cache and reloading...")
        hasLoadedData = false
        clearCache() // Clear spot details cache
        loadFeed()
    }
    
    // Add a method to manually refresh after rating submission
    func refreshAfterRatingSubmission() {
        print("🔄 Manually refreshing feed after rating submission...")
        refreshFeed()
    }
    
    // Add a method to listen for rating updates
    func startListeningForRatingUpdates() {
        print("🔥 Setting up Firestore listener for rating updates...")
        // Listen for changes in the ratings collection
        db.collection("ratings")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ Error listening for rating updates: \(error.localizedDescription)")
                    return
                }
                
                // If there are changes, refresh the feed
                if let snapshot = snapshot, !snapshot.documentChanges.isEmpty {
                    print("🔄 Rating changes detected, refreshing feed...")
                    print("🔄 Document changes: \(snapshot.documentChanges.count)")
                    for change in snapshot.documentChanges {
                        print("🔄 Change type: \(change.type.rawValue), document ID: \(change.document.documentID)")
                    }
                    DispatchQueue.main.async(execute: DispatchWorkItem {
                        self.refreshFeed()
                    })
                }
            }
    }
    
    // Add a method to stop listening for rating updates
    func stopListeningForRatingUpdates() {
        // The snapshot listener will be automatically removed when the view disappears
        // This method is here for future use if we need to manually control the listener
    }
    
    // Add a method to listen for rating update notifications
    func startListeningForNotifications() {
        print("🔔 Setting up notification listener for rating updates...")
        NotificationCenter.default.addObserver(
            forName: .ratingUpdated,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("🔄 Rating update notification received, refreshing feed...")
            self?.refreshFeed()
        }
    }
    
    // Add a method to stop listening for notifications
    func stopListeningForNotifications() {
        NotificationCenter.default.removeObserver(self, name: .ratingUpdated, object: nil)
    }
    
    // Add a method to validate rating data
    private func validateRatingData(_ feedItem: ReviewFeedItem) {
        // Data validation is now handled by the UI showing "NR" for missing fields
        // No need for console warnings
    }
    
    // Clean up notification observers
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func loadFeed() {
        // Prevent multiple simultaneous loads
        if isLoading && hasLoadedData {
            return
        }
        
        print("🔄 Starting to load feed...")
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
        DispatchQueue.main.async(execute: DispatchWorkItem {
            self.error = "Some data may not be available due to permission settings. The app will continue to work with available information."
        })
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
            DispatchQueue.main.async(execute: DispatchWorkItem {
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
                        DispatchQueue.main.async(execute: DispatchWorkItem {
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
                            print("✅ Friend feed loaded successfully with \(documents.count) ratings")
                        })
                    }
            })
        }
    }
    
    private func loadFriendRatingsDirectly(currentUserId: String) {
        // Get user's friends list
        db.collection("users").document(currentUserId).getDocument { snapshot, error in
            DispatchQueue.main.async(execute: DispatchWorkItem {
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
                
                // Load ratings from friends (respect privacy settings)
                self.db.collection("ratings")
                    .whereField("userId", in: friends)
                    .whereField("visibility", in: ["public", "friends"]) // Show public and friends-only reviews
                    .order(by: "timestamp", descending: true)
                    .limit(to: 20)
                    .getDocuments { snapshot, error in
                        DispatchQueue.main.async(execute: DispatchWorkItem {
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
                        })
                    }
            })
        }
    }
    
    private func loadCommunityRatings() {
        // Optimize initial load - start with smaller batch
        let initialLimit = initialLoadComplete ? 20 : 10
        
        // Add a timeout to prevent hanging
        let timeoutTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { _ in
            DispatchQueue.main.async(execute: DispatchWorkItem {
                if self.isLoading {
                    self.isLoading = false
                    self.reviews = []
                    self.filteredReviews = []
                    self.error = "Loading timeout - please try again"
                }
            })
        }
        
        // 🔒 Filter by privacy settings - show public ratings and ratings without visibility field (legacy)
        // First try to get public ratings, then fallback to all ratings if none found
        db.collection("ratings")
            .whereField("visibility", isEqualTo: "public")
            .order(by: "timestamp", descending: true)
            .limit(to: initialLimit)
            .getDocuments { [weak self] snapshot, error in
                timeoutTimer.invalidate() // Cancel timeout if we get a response
                
                if error != nil || snapshot?.documents.isEmpty == true {
                    // Fallback: get all ratings without visibility filter
                    self?.loadAllCommunityRatings(limit: initialLimit)
                } else {
                    // Process public ratings
                    self?.processRatingDocuments(snapshot?.documents ?? [])
                    self?.hasLoadedData = true
                    self?.initialLoadComplete = true
                    print("✅ Community feed loaded successfully with \(snapshot?.documents.count ?? 0) public ratings")
                }
            }
    }
    
    private func loadAllCommunityRatings(limit: Int) {
        // Fallback: load all ratings without visibility filter for legacy support
        db.collection("ratings")
            .order(by: "timestamp", descending: true)
            .limit(to: limit)
            .getDocuments { [weak self] snapshot, error in
                DispatchQueue.main.async(execute: DispatchWorkItem {
                    self?.isLoading = false
                    
                    if let error = error {
                        self?.error = error.localizedDescription
                        return
                    }
                    
                    guard let documents = snapshot?.documents else {
                        self?.reviews = []
                        self?.filteredReviews = []
                        return
                    }
                    
                    self?.processRatingDocuments(documents)
                    self?.hasLoadedData = true
                    self?.initialLoadComplete = true
                    print("✅ Community feed loaded successfully with \(documents.count) ratings (legacy mode)")
                })
            }
    }
    
    private func processRatingDocuments(_ documents: [QueryDocumentSnapshot]) {
        // Process documents on background queue to avoid blocking main thread
        DispatchQueue.global(qos: .userInitiated).async(execute: DispatchWorkItem {
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
                
                // Extract rating details with robust type handling
                let creaminessRating = self.extractCreaminessRating(from: data["creaminessRating"])
                let chaiStrengthRating = self.extractChaiStrengthRating(from: data["chaiStrengthRating"])
                let flavorNotes = self.extractFlavorNotes(from: data["flavorNotes"])
                
                // Create ReviewFeedItem
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
                    chaiType: chaiType,
                    creaminessRating: creaminessRating,
                    chaiStrengthRating: chaiStrengthRating,
                    flavorNotes: flavorNotes,
                    photoURL: data["photoURL"] as? String,
                    hasPhoto: data["hasPhoto"] as? Bool ?? false,
                    gamificationScore: data["gamificationScore"] as? Int ?? 0,
                    isFirstReview: data["isFirstReview"] as? Bool ?? false,
                    isNewSpot: data["isNewSpot"] as? Bool ?? false
                )
                
                return feedItem
            }
            
            print("📊 Total feed items created: \(feedItems.count)")
            
            // Update UI on main thread
            DispatchQueue.main.async(execute: DispatchWorkItem {
                self.reviews = feedItems.sorted { $0.timestamp > $1.timestamp }
                self.filteredReviews = self.reviews
                
                print("📊 Updated reviews array with \(self.reviews.count) items")
                
                // Validate rating data for debugging
                for feedItem in feedItems {
                    self.validateRatingData(feedItem)
                }
                
                // Load spot details asynchronously after initial load
                for feedItem in feedItems {
                    self.loadSpotDetails(for: feedItem.spotId) { spotName, spotAddress in
                        DispatchQueue.main.async(execute: DispatchWorkItem {
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
                        })
                    }
                }
            })
        })
    }
    
    private func processFriendRatingDocuments(_ documents: [QueryDocumentSnapshot]) {
        // Process documents on background queue to avoid blocking main thread
        DispatchQueue.global(qos: .userInitiated).async(execute: DispatchWorkItem {
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
                
                // Extract rating details with robust type handling
                let creaminessRating = self.extractCreaminessRating(from: data["creaminessRating"])
                let chaiStrengthRating = self.extractChaiStrengthRating(from: data["chaiStrengthRating"])
                let flavorNotes = self.extractFlavorNotes(from: data["flavorNotes"])
                
                // Create ReviewFeedItem
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
                    chaiType: chaiType,
                    creaminessRating: creaminessRating,
                    chaiStrengthRating: chaiStrengthRating,
                    flavorNotes: flavorNotes,
                    photoURL: data["photoURL"] as? String,
                    hasPhoto: data["hasPhoto"] as? Bool ?? false,
                    gamificationScore: data["gamificationScore"] as? Int ?? 0,
                    isFirstReview: data["isFirstReview"] as? Bool ?? false,
                    isNewSpot: data["isNewSpot"] as? Bool ?? false
                )
                
                return feedItem
            }
            
            print("📊 Total friend feed items created: \(feedItems.count)")
            
            // Update UI on main thread
            DispatchQueue.main.async(execute: DispatchWorkItem {
                self.reviews = feedItems.sorted { $0.timestamp > $1.timestamp }
                self.filteredReviews = self.reviews
                
                print("📊 Updated friend reviews array with \(self.reviews.count) items")
                
                // Validate rating data for debugging
                for feedItem in feedItems {
                    self.validateRatingData(feedItem)
                }
                
                // Load spot details asynchronously after initial load
                for feedItem in feedItems {
                    self.loadSpotDetails(for: feedItem.spotId) { spotName, spotAddress in
                        DispatchQueue.main.async(execute: DispatchWorkItem {
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
                        })
                    }
                }
            })
        })
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
        
        // Try both collections - chaiFinder and chaiSpots
        let collections = ["chaiFinder", "chaiSpots"]
        var currentCollectionIndex = 0
        
        func tryNextCollection() {
            guard currentCollectionIndex < collections.count else {
                // All collections failed, use fallback
                let fallbackName = "Chai Spot #\(spotId.prefix(6))"
                let fallbackAddress = "Location details unavailable"
                self.spotDetailsCache[spotId] = (fallbackName, fallbackAddress)
                completion(fallbackName, fallbackAddress)
                return
            }
            
            let collectionName = collections[currentCollectionIndex]
            currentCollectionIndex += 1
            
            db.collection(collectionName).document(spotId).getDocument { snapshot, error in
                DispatchQueue.main.async {
                    if let error = error {
                        // Try the next collection if this one failed
                        print("Failed to load from collection \(collectionName): \(error.localizedDescription)")
                        tryNextCollection()
                        return
                    }
                    
                    guard let data = snapshot?.data(),
                          let name = data["name"] as? String,
                          let address = data["address"] as? String else {
                        // Data is missing, try the next collection
                        print("Missing data from collection \(collectionName)")
                        tryNextCollection()
                        return
                    }
                    
                    // Successfully loaded spot details
                    self.loadingSpots.remove(spotId)
                    self.spotDetailsCache[spotId] = (name, address)
                    completion(name, address)
                }
            }
        }
        
        tryNextCollection()
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
    
    // MARK: - Helper Methods
    
    private func formatTimestamp(_ timestamp: Timestamp) -> String {
        let date = timestamp.dateValue()
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    // Helper methods for robust rating data extraction
    private func extractCreaminessRating(from value: Any?) -> Int? {
        if let intValue = value as? Int {
            return intValue
        }
        if let doubleValue = value as? Double {
            return Int(doubleValue)
        }
        if let stringValue = value as? String {
            return Int(stringValue)
        }
        return nil
    }
    
    private func extractChaiStrengthRating(from value: Any?) -> Int? {
        if let intValue = value as? Int {
            return intValue
        }
        if let doubleValue = value as? Double {
            return Int(doubleValue)
        }
        if let stringValue = value as? String {
            return Int(stringValue)
        }
        return nil
    }
    
    private func extractFlavorNotes(from value: Any?) -> [String]? {
        if let arrayValue = value as? [String] {
            return arrayValue
        }
        if let stringValue = value as? String {
            // Handle case where flavorNotes might be saved as a single string
            return [stringValue]
        }
        return nil
    }
} 