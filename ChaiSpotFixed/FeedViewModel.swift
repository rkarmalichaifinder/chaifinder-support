import SwiftUI
import Firebase
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore

// 🆕 Search feedback types
enum SearchType {
    case none
    case flavorNotes
    case location
    case user
    case general
}

struct SearchFeedback {
    let resultCount: Int
    let searchType: SearchType
    let message: String
}

enum FeedType {
    case friends
    case community
}

class FeedViewModel: ObservableObject {
    @Published var feedItems: [FeedItem] = []
    @Published var filteredFeedItems: [FeedItem] = []
    @Published var reviews: [ReviewFeedItem] = []
    @Published var filteredReviews: [ReviewFeedItem] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var currentFeedType: FeedType = .friends
    @Published var initialLoadComplete = false
    @Published var isSwitchingFeedType = false
    
    private lazy var db: Firestore = {
        // Only create Firestore instance when actually needed
        // Firebase should be configured by SessionStore before this is called
        return Firestore.firestore()
    }()
    private var spotDetailsCache: [String: (name: String, address: String)] = [:]
    private var loadingSpots: Set<String> = []
    private var hasLoadedData = false
    
    // 🆕 Debounced reaction updates
    private var reactionUpdateTimer: Timer?
    private var pendingReactionUpdates: Set<String> = []
    
    // 🆕 Real-time listeners
    private var usersListener: ListenerRegistration?
    private var spotsListener: ListenerRegistration?
    private var ratingsListener: ListenerRegistration?
    private var achievementsListener: ListenerRegistration?
    
    // 🆕 Smart notification manager
    private let notificationManager = SmartNotificationManager.shared
    
    // 🆕 Search debouncing
    private var searchDebounceTimer: Timer?
    private var lastSearchText: String = ""
    
    // MARK: - Data Migration Functions
    
    /// Backfills existing ratings documents with default visibility and deleted fields
    /// This should be run once to migrate old data to the new schema
    func backfillRatingsDefaults(batchSize: Int = 300, completion: @escaping (Error?) -> Void) {
        print("🔄 Starting ratings data migration...")
        let db = Firestore.firestore()
        var lastDoc: DocumentSnapshot?
        var totalProcessed = 0
        var totalUpdated = 0

        func processBatch() {
            var query: Query = db.collection("ratings")
                .order(by: FieldPath.documentID())
                .limit(to: batchSize)

            if let last = lastDoc { 
                query = query.start(afterDocument: last) 
            }

            query.getDocuments { snapshot, error in
                if let error = error { 
                    print("❌ Migration error: \(error.localizedDescription)")
                    completion(error)
                    return 
                }
                
                guard let snapshot = snapshot, !snapshot.documents.isEmpty else { 
                    print("✅ Migration completed! Total processed: \(totalProcessed), Total updated: \(totalUpdated)")
                    completion(nil)
                    return 
                }

                let batch = db.batch()
                var batchUpdated = 0
                
                for doc in snapshot.documents {
                    let data = doc.data()
                    var needsUpdate = false
                    var patch: [String: Any] = [:]

                    // Add visibility field if missing (default to "public")
                    if data["visibility"] == nil {
                        patch["visibility"] = "public"
                        needsUpdate = true
                    }
                    
                    // Add deleted field if missing (default to false)
                    if data["deleted"] == nil {
                        patch["deleted"] = false
                        needsUpdate = true
                    }
                    
                    if needsUpdate { 
                        batch.updateData(patch, forDocument: doc.reference)
                        batchUpdated += 1
                    }
                }

                if batchUpdated > 0 {
                    batch.commit { batchError in
                        if let batchError = batchError { 
                            print("❌ Batch commit error: \(batchError.localizedDescription)")
                            completion(batchError)
                            return 
                        }
                        
                        totalProcessed += snapshot.documents.count
                        totalUpdated += batchUpdated
                        print("🔄 Processed batch: \(snapshot.documents.count) docs, updated: \(batchUpdated). Total: \(totalProcessed)/\(totalUpdated)")
                        
                        lastDoc = snapshot.documents.last
                        processBatch()
                    }
                } else {
                    // No updates needed in this batch, continue to next
                    totalProcessed += snapshot.documents.count
                    lastDoc = snapshot.documents.last
                    processBatch()
                }
            }
        }
        
        processBatch()
    }
    
    // MARK: - Enhanced Query Functions with Fallbacks
    
    /// Loads friend ratings with fallback to legacy data if filtered query returns no results
    private func loadFriendRatingsWithFallback(currentUserId: String, friends: [String]) {
        // Use the original simple query that was working before
        let query = db.collection("ratings")
            .whereField("userId", in: friends)
            .order(by: "timestamp", descending: true)
            .limit(to: 20)
        
        query.getDocuments { [weak self] snapshot, error in
            if let error = error {
                print("❌ Friends query failed: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self?.isLoading = false
                    self?.isSwitchingFeedType = false
                    self?.reviews = []
                    self?.filteredReviews = []
                    self?.error = "Unable to load friend reviews. Please try again."
                }
                return
            }
            
            guard let documents = snapshot?.documents else {
                DispatchQueue.main.async {
                    self?.isLoading = false
                    self?.isSwitchingFeedType = false
                    self?.reviews = []
                    self?.filteredReviews = []
                    self?.error = "Your friends haven't posted any reviews yet."
                }
                return
            }
            
            if documents.isEmpty {
                DispatchQueue.main.async {
                    self?.isLoading = false
                    self?.isSwitchingFeedType = false
                    self?.reviews = []
                    self?.filteredReviews = []
                    self?.error = "Your friends haven't posted any reviews yet."
                }
                return
            }
            
            // Success with original query
            DispatchQueue.main.async {
                self?.isLoading = false
                self?.isSwitchingFeedType = false
                self?.processFriendRatingDocuments(documents)
                self?.hasLoadedData = true
                print("✅ Friend feed loaded successfully with \(documents.count) ratings")
            }
        }
    }
    
    /// Legacy fallback for friend ratings (no visibility/deleted filters)
    private func loadLegacyFriendRatings(currentUserId: String, friends: [String]) {
        print("🔄 Loading legacy friend ratings...")
        
        // First try to load some recent ratings that might have photos
        let recentQuery = db.collection("ratings")
            .order(by: "timestamp", descending: true)
            .limit(to: 10)
        
        recentQuery.getDocuments { [weak self] snapshot, error in
            if let documents = snapshot?.documents, !documents.isEmpty {
                print("🔍 Found \(documents.count) recent ratings, checking for photos...")
                
                // Check if any have photos
                let ratingsWithPhotos = documents.filter { doc in
                    let data = doc.data()
                    let hasPhoto = data["photoURL"] as? String != nil && !(data["photoURL"] as? String ?? "").isEmpty
                    if hasPhoto {
                        print("🎉 Found rating with photo: \(doc.documentID)")
                    }
                    return hasPhoto
                }
                
                if !ratingsWithPhotos.isEmpty {
                    print("✅ Found \(ratingsWithPhotos.count) ratings with photos - processing these first!")
                    DispatchQueue.main.async {
                        self?.processFriendRatingDocuments(ratingsWithPhotos)
                        self?.hasLoadedData = true
                        self?.isLoading = false
                        self?.isSwitchingFeedType = false
                    }
                    return
                }
            }
            
            // Fallback to original legacy query
            let legacyQuery = self?.db.collection("ratings")
                .whereField("userId", in: friends)
                .order(by: "timestamp", descending: true)
                .limit(to: 20)
        
            legacyQuery?.getDocuments { [weak self] snapshot, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                self?.isSwitchingFeedType = false
                
                if let error = error {
                    self?.reviews = []
                    self?.filteredReviews = []
                    self?.error = "Unable to load friend reviews. Please try again."
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    self?.reviews = []
                    self?.filteredReviews = []
                    self?.error = "Your friends haven't posted any reviews yet."
                    return
                }
                
                if documents.isEmpty {
                    self?.reviews = []
                    self?.filteredReviews = []
                    self?.error = "Your friends haven't posted any reviews yet."
                    return
                }
                
                self?.processFriendRatingDocuments(documents)
                self?.hasLoadedData = true
                print("✅ Friend feed loaded successfully with \(documents.count) legacy ratings")
            }
        }
    }
    }
    
    /// Loads community ratings with fallback to legacy data
    private func loadCommunityRatingsWithFallback() {
        let initialLimit = initialLoadComplete ? 20 : 10
        
        // Use the original simple query that was working before
        let query = db.collection("ratings")
            .order(by: "timestamp", descending: true)
            .limit(to: initialLimit)
        
        query.getDocuments { [weak self] snapshot, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                self?.isSwitchingFeedType = false
                
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
                print("✅ Community feed loaded successfully with \(documents.count) ratings")
            }
        }
    }
    
    /// Legacy fallback for community ratings
    private func loadLegacyCommunityRatings(limit: Int) {
        print("🔄 Loading legacy community ratings...")
        db.collection("ratings")
            .order(by: "timestamp", descending: true)
            .limit(to: limit)
            .getDocuments { [weak self] snapshot, error in
                DispatchQueue.main.async {
                    self?.isLoading = false
                    self?.isSwitchingFeedType = false
                    
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
                    print("✅ Community feed loaded successfully with \(documents.count) legacy ratings")
                }
            }
    }
    
    // Add a method to refresh the feed
    func refreshFeed() {
        print("🔄 refreshFeed() called - clearing cache and reloading...")
        hasLoadedData = false
        isSwitchingFeedType = false
        clearCache() // Clear spot details cache
        loadFeed()
    }
    
    // Add a method to manually refresh after rating submission
    func refreshAfterRatingSubmission() {
        print("🔄 Manually refreshing feed after rating submission...")
        refreshFeed()
    }
    
    // 🆕 Smart refresh method that can update only changed items
    func smartRefreshFeed(changedItems: [String]? = nil) {
        if let changedItems = changedItems, !changedItems.isEmpty {
            print("🔄 Smart refresh: Updating \(changedItems.count) changed items...")
            updateChangedItems(changedItems)
        } else {
            print("🔄 Smart refresh: No specific changes, doing full refresh...")
            refreshFeed()
        }
    }
    
    // 🆕 Update only specific changed items in the feed
    private func updateChangedItems(_ itemIds: [String]) {
        guard !itemIds.isEmpty else { return }
        
        let db = Firestore.firestore()
        
        // Get the updated documents using individual gets
        let group = DispatchGroup()
        var documents: [DocumentSnapshot] = []
        
        for itemId in itemIds {
            group.enter()
            let docRef = db.collection("ratings").document(itemId)
            docRef.getDocument { snapshot, error in
                defer { group.leave() }
                if let snapshot = snapshot, snapshot.exists {
                    documents.append(snapshot)
                }
            }
        }
        
        group.notify(queue: .main) {
            // Update the feed with the new documents
            for document in documents {
                self.updateFeedItem(with: document)
            }
        }
    }
    
    // 🆕 Update a single feed item with new data
    private func updateFeedItem(with document: DocumentSnapshot) {
        guard let data = document.data() else { return }
        
        DispatchQueue.main.async {
            // Find and update the item in our reviews array
            if let index = self.reviews.firstIndex(where: { $0.id == document.documentID }) {
                // Update the existing item with new data
                var updatedItem = self.reviews[index]
                
                // Update reaction counts if they exist
                if let reactions = data["reactions"] as? [String: Int] {
                    // Note: We need to make reactions mutable in ReviewFeedItem
                    // For now, we'll refresh the entire feed
                    print("🔄 Reactions updated, refreshing entire feed for now...")
                    self.refreshFeed()
                    return
                }
                
                // Update other fields as needed
                if let comment = data["comment"] as? String {
                    // Note: We need to make comment mutable in ReviewFeedItem
                    // For now, we'll refresh the entire feed
                    print("🔄 Comment updated, refreshing entire feed for now...")
                    self.refreshFeed()
                    return
                }
                
                // If no special handling needed, just refresh the feed
                self.refreshFeed()
            }
        }
    }
    
    // 🆕 Schedule a debounced reaction update
    private func scheduleReactionUpdate() {
        // Cancel existing timer
        reactionUpdateTimer?.invalidate()
        
        // Schedule new timer with 300ms delay
        reactionUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                self?.processPendingReactionUpdates()
            }
        }
    }
    
    // 🆕 Process all pending reaction updates at once
    private func processPendingReactionUpdates() {
        guard !pendingReactionUpdates.isEmpty else { return }
        
        print("🔄 Processing \(pendingReactionUpdates.count) pending reaction updates...")
        
        // For now, we'll do a full refresh since we need to update reaction counts
        // In the future, we could implement more granular updates
        refreshFeed()
        
        // Clear pending updates
        pendingReactionUpdates.removeAll()
    }
    
    // MARK: - Debug and Migration Functions
    
    /// Triggers the data migration process (call this once to fix the feed switching issue)
    func triggerDataMigration() {
        print("🚀 Triggering data migration...")
        backfillRatingsDefaults { error in
            if let error = error {
                print("❌ Migration failed: \(error.localizedDescription)")
            } else {
                print("✅ Migration completed successfully!")
                // Refresh the feed after migration
                DispatchQueue.main.async {
                    self.refreshFeed()
                }
            }
        }
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
        print("🔔 Setting up comprehensive notification listeners...")
        
        // Listen for rating updates
        NotificationCenter.default.addObserver(
            forName: .ratingUpdated,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("🔄 Rating update notification received, refreshing feed...")
            self?.refreshFeed()
        }
        
        // 🆕 Listen for reaction updates
        NotificationCenter.default.addObserver(
            forName: .reactionUpdated,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("🔄 Reaction update notification received, scheduling debounced update...")
            self?.scheduleReactionUpdate()
        }
        
        // 🆕 Listen for comment engagement updates
        NotificationCenter.default.addObserver(
            forName: .commentEngagementUpdated,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("🔄 Comment engagement update notification received, refreshing feed...")
            self?.refreshFeed()
        }
        
        // 🆕 Listen for review visibility changes
        NotificationCenter.default.addObserver(
            forName: .reviewVisibilityChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("🔄 Review visibility change notification received, refreshing feed...")
            self?.refreshFeed()
        }
        
        // 🆕 Listen for new user joins
        NotificationCenter.default.addObserver(
            forName: .newUserJoined,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            print("🆕 New user joined notification received")
            if let userData = notification.userInfo?["userData"] as? [String: Any] {
                self?.handleNewUserJoined(userData)
            }
        }
        
        // 🆕 Listen for new spot additions
        NotificationCenter.default.addObserver(
            forName: .newSpotAdded,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            print("🆕 New spot added notification received")
            if let spotData = notification.userInfo?["spotData"] as? [String: Any] {
                self?.handleNewSpotAdded(spotData)
            }
        }
        
        // 🆕 Listen for friend activity
        NotificationCenter.default.addObserver(
            forName: .friendActivity,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            print("🆕 Friend activity notification received")
            if let activityData = notification.userInfo?["activityData"] as? [String: Any] {
                self?.handleFriendActivity(activityData)
            }
        }
        
        // 🆕 Listen for achievements
        NotificationCenter.default.addObserver(
            forName: .achievementEarned,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            print("🆕 Achievement earned notification received")
            if let achievementData = notification.userInfo?["achievementData"] as? [String: Any] {
                self?.handleAchievementEarned(achievementData)
            }
        }
        
        // 🆕 Listen for weekly challenges
        NotificationCenter.default.addObserver(
            forName: .weeklyChallenge,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            print("🆕 Weekly challenge notification received")
            if let challengeData = notification.userInfo?["challengeData"] as? [String: Any] {
                self?.handleWeeklyChallenge(challengeData)
            }
        }
        
        // 🆕 Listen for general feed refresh
        NotificationCenter.default.addObserver(
            forName: .feedRefreshNeeded,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("🔄 Feed refresh needed notification received")
            self?.refreshFeed()
        }
        
        // 🆕 Set up real-time Firestore listeners
        setupRealTimeListeners()
    }
    
    // Add a method to stop listening for notifications
    func stopListeningForNotifications() {
        NotificationCenter.default.removeObserver(self, name: .ratingUpdated, object: nil)
        NotificationCenter.default.removeObserver(self, name: .reactionUpdated, object: nil)
        NotificationCenter.default.removeObserver(self, name: .commentEngagementUpdated, object: nil)
        NotificationCenter.default.removeObserver(self, name: .reviewVisibilityChanged, object: nil)
        NotificationCenter.default.removeObserver(self, name: .newUserJoined, object: nil)
        NotificationCenter.default.removeObserver(self, name: .newSpotAdded, object: nil)
        NotificationCenter.default.removeObserver(self, name: .friendActivity, object: nil)
        NotificationCenter.default.removeObserver(self, name: .achievementEarned, object: nil)
        NotificationCenter.default.removeObserver(self, name: .weeklyChallenge, object: nil)
        NotificationCenter.default.removeObserver(self, name: .feedRefreshNeeded, object: nil)
        
        // 🆕 Remove real-time listeners
        removeRealTimeListeners()
    }
    
    // Add a method to validate rating data
    private func validateRatingData(_ feedItem: ReviewFeedItem) {
        // Data validation is now handled by the UI showing "NR" for missing fields
        // No need for console warnings
    }
    
    // Clean up notification observers
    deinit {
        NotificationCenter.default.removeObserver(self)
        reactionUpdateTimer?.invalidate()
        reactionUpdateTimer = nil
        removeRealTimeListeners()
    }
    
    // MARK: - Real-time Listeners Setup
    
    private func setupRealTimeListeners() {
        print("🎧 Setting up real-time Firestore listeners...")
        
        // Listen for new users (limited to recent users to avoid overwhelming)
        setupUsersListener()
        
        // Listen for new spots
        setupSpotsListener()
        
        // Listen for new ratings with enhanced filtering
        setupRatingsListener()
        
        // Listen for achievements
        setupAchievementsListener()
    }
    
    private func removeRealTimeListeners() {
        usersListener?.remove()
        spotsListener?.remove()
        ratingsListener?.remove()
        achievementsListener?.remove()
        
        usersListener = nil
        spotsListener = nil
        ratingsListener = nil
        achievementsListener = nil
    }
    
    private func setupUsersListener() {
        // Only listen for users created in the last 24 hours to avoid overwhelming
        let oneDayAgo = Timestamp(date: Date().addingTimeInterval(-86400))
        
        usersListener = db.collection("users")
            .whereField("createdAt", isGreaterThan: oneDayAgo)
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    print("❌ Users listener error: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                for change in snapshot?.documentChanges ?? [] {
                    if change.type == .added {
                        self?.handleNewUserDocument(change.document)
                    }
                }
            }
    }
    
    private func setupSpotsListener() {
        // Listen for new spots in both collections
        let oneDayAgo = Timestamp(date: Date().addingTimeInterval(-86400))
        
        spotsListener = db.collection("chaiFinder")
            .whereField("createdAt", isGreaterThan: oneDayAgo)
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    print("❌ Spots listener error: \(error.localizedDescription)")
                    return
                }
                
                for change in snapshot?.documentChanges ?? [] {
                    if change.type == .added {
                        self?.handleNewSpotDocument(change.document)
                    }
                }
            }
    }
    
    private func setupRatingsListener() {
        // Enhanced ratings listener with better filtering
        let oneDayAgo = Timestamp(date: Date().addingTimeInterval(-86400))
        
        ratingsListener = db.collection("ratings")
            .whereField("timestamp", isGreaterThan: oneDayAgo)
            .whereField("deleted", isEqualTo: false)
            .order(by: "timestamp", descending: true)
            .limit(to: 50)
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    print("❌ Ratings listener error: \(error.localizedDescription)")
                    return
                }
                
                for change in snapshot?.documentChanges ?? [] {
                    if change.type == .added {
                        self?.handleNewRatingDocument(change.document)
                    }
                }
            }
    }
    
    private func setupAchievementsListener() {
        // Listen for new achievements
        let oneDayAgo = Timestamp(date: Date().addingTimeInterval(-86400))
        
        achievementsListener = db.collection("achievements")
            .whereField("timestamp", isGreaterThan: oneDayAgo)
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    print("❌ Achievements listener error: \(error.localizedDescription)")
                    return
                }
                
                for change in snapshot?.documentChanges ?? [] {
                    if change.type == .added {
                        self?.handleNewAchievementDocument(change.document)
                    }
                }
            }
    }
    
    // MARK: - Notification Handlers
    
    private func handleNewUserJoined(_ userData: [String: Any]) {
        guard let feedItem = FeedItemFactory.createFeedItem(from: userData, documentId: UUID().uuidString) else {
            return
        }
        
        DispatchQueue.main.async {
            self.addFeedItem(feedItem)
            self.notificationManager.showNotification(for: feedItem)
        }
    }
    
    private func handleNewSpotAdded(_ spotData: [String: Any]) {
        guard let feedItem = FeedItemFactory.createFeedItem(from: spotData, documentId: UUID().uuidString) else {
            return
        }
        
        DispatchQueue.main.async {
            self.addFeedItem(feedItem)
            self.notificationManager.showNotification(for: feedItem)
        }
    }
    
    private func handleFriendActivity(_ activityData: [String: Any]) {
        guard let feedItem = FeedItemFactory.createFeedItem(from: activityData, documentId: UUID().uuidString) else {
            return
        }
        
        DispatchQueue.main.async {
            self.addFeedItem(feedItem)
            self.notificationManager.showNotification(for: feedItem)
        }
    }
    
    private func handleAchievementEarned(_ achievementData: [String: Any]) {
        guard let feedItem = FeedItemFactory.createFeedItem(from: achievementData, documentId: UUID().uuidString) else {
            return
        }
        
        DispatchQueue.main.async {
            self.addFeedItem(feedItem)
            self.notificationManager.showNotification(for: feedItem)
        }
    }
    
    private func handleWeeklyChallenge(_ challengeData: [String: Any]) {
        guard let feedItem = FeedItemFactory.createFeedItem(from: challengeData, documentId: UUID().uuidString) else {
            return
        }
        
        DispatchQueue.main.async {
            self.addFeedItem(feedItem)
            self.notificationManager.showNotification(for: feedItem)
        }
    }
    
    // MARK: - Document Handlers
    
    private func handleNewUserDocument(_ document: DocumentSnapshot) {
        var data = document.data() ?? [:]
        data["type"] = "newUser"
        data["timestamp"] = Timestamp()
        
        handleNewUserJoined(data)
    }
    
    private func handleNewSpotDocument(_ document: DocumentSnapshot) {
        var data = document.data() ?? [:]
        data["type"] = "newSpot"
        data["timestamp"] = Timestamp()
        
        handleNewSpotAdded(data)
    }
    
    private func handleNewRatingDocument(_ document: DocumentSnapshot) {
        var data = document.data() ?? [:]
        data["type"] = "review"
        
        // Only show notification for public reviews
        if data["visibility"] as? String == "public" {
            if let feedItem = FeedItemFactory.createFeedItem(from: data, documentId: document.documentID) {
                DispatchQueue.main.async {
                    self.notificationManager.showNotification(for: feedItem)
                }
            }
        }
    }
    
    private func handleNewAchievementDocument(_ document: DocumentSnapshot) {
        var data = document.data() ?? [:]
        data["type"] = "achievement"
        data["timestamp"] = Timestamp()
        
        handleAchievementEarned(data)
    }
    
    // MARK: - Feed Item Management
    
    private func addFeedItem(_ item: FeedItem) {
        // Add to the beginning of the feed
        feedItems.insert(item, at: 0)
        
        // Keep only the last 100 items to prevent memory issues
        if feedItems.count > 100 {
            feedItems = Array(feedItems.prefix(100))
        }
        
        // Update filtered items
        filterFeedItems()
    }
    
    private func filterFeedItems() {
        // For now, just copy all items. Can be enhanced with search/filtering later
        filteredFeedItems = feedItems
    }
    
    func loadFeed() {
        // Prevent multiple simultaneous loads only if we're not switching feed types
        if isLoading && hasLoadedData && !isSwitchingFeedType {
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
        isSwitchingFeedType = true
        
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
        isSwitchingFeedType = false
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
                    self.isSwitchingFeedType = false
                    self.reviews = []
                    self.filteredReviews = []
                    self.error = "Unable to load friends list. Please check your connection."
                    return
                }
                
                guard let data = snapshot?.data(),
                      let friends = data["friends"] as? [String],
                      !friends.isEmpty else {
                    self.isLoading = false
                    self.isSwitchingFeedType = false
                    self.reviews = []
                    self.filteredReviews = []
                    self.error = "You don't have any friends yet. Add friends to see their reviews here!"
                    return
                }
                
                // Use enhanced query with fallback
                self.loadFriendRatingsWithFallback(currentUserId: currentUserId, friends: friends)
            })
        }
    }
    
    private func loadFriendRatingsDirectly(currentUserId: String) {
        // Get user's friends list
        db.collection("users").document(currentUserId).getDocument { snapshot, error in
            DispatchQueue.main.async(execute: DispatchWorkItem {
                if let error = error {
                    self.isLoading = false
                    self.isSwitchingFeedType = false
                    self.reviews = []
                    self.filteredReviews = []
                    self.error = "Unable to load friends list. Please check your connection."
                    return
                }
                
                guard let data = snapshot?.data(),
                      let friends = data["friends"] as? [String] else {
                    self.isLoading = false
                    self.isSwitchingFeedType = false
                    self.reviews = []
                    self.filteredReviews = []
                    self.error = "You don't have any friends yet. Add friends to see their reviews here!"
                    return
                }
                
                if friends.isEmpty {
                    self.isLoading = false
                    self.isSwitchingFeedType = false
                    self.reviews = []
                    self.filteredReviews = []
                    self.error = "You don't have any friends yet. Add friends to see their reviews here!"
                    return
                }
                
                // Use enhanced query with fallback
                self.loadFriendRatingsWithFallback(currentUserId: currentUserId, friends: friends)
            })
        }
    }
    
    private func loadCommunityRatings() {
        // Use enhanced query with fallback
        loadCommunityRatingsWithFallback()
    }
    
    private func loadAllCommunityRatings(limit: Int) {
        // Fallback: load all ratings without visibility filter for legacy support
        db.collection("ratings")
            .order(by: "timestamp", descending: true)
            .limit(to: limit)
            .getDocuments { [weak self] snapshot, error in
                DispatchQueue.main.async(execute: DispatchWorkItem {
                    self?.isLoading = false
                    self?.isSwitchingFeedType = false
                    
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
                
                let username = data["username"] as? String ?? data["userName"] as? String ?? "Anonymous"
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
                    likes: data["likes"] as? Int ?? 0,
                    dislikes: data["dislikes"] as? Int ?? 0,
                    isRead: false,
                    visibility: data["visibility"] as? String ?? "public",
                    deleted: data["deleted"] as? Bool ?? false,
                    updatedAt: data["updatedAt"] as? Timestamp
                )
                
                return feedItem
            }
            
            print("📊 Total feed items created: \(feedItems.count)")
            
            // Update UI on main thread
            DispatchQueue.main.async(execute: DispatchWorkItem {
                self.isLoading = false
                self.isSwitchingFeedType = false
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
                
                let username = data["username"] as? String ?? data["userName"] as? String ?? "Anonymous"
                let comment = data["comment"] as? String
                let timestamp = data["timestamp"] as? Timestamp
                let chaiType = data["chaiType"] as? String
                
                // Check if spot details are already stored in the rating
                let spotName = data["spotName"] as? String
                let spotAddress = data["spotAddress"] as? String
                
                if let storedName = spotName, let storedAddress = spotAddress {
                    print("✅ Rating for spot \(spotId) already has stored details: \(storedName)")
                } else {
                    print("⚠️ Rating for spot \(spotId) missing stored details, will need to fetch from collections")
                }
                
                // Extract rating details with robust type handling
                let creaminessRating = self.extractCreaminessRating(from: data["creaminessRating"])
                let chaiStrengthRating = self.extractChaiStrengthRating(from: data["chaiStrengthRating"])
                let flavorNotes = self.extractFlavorNotes(from: data["flavorNotes"])
                
                // Debug: Log photo data
                let photoURL = data["photoURL"] as? String
                let hasPhoto = data["hasPhoto"] as? Bool ?? false
                print("🔍 Rating \(document.documentID) photo data: photoURL=\(photoURL ?? "nil"), hasPhoto=\(hasPhoto)")
                
                // Create ReviewFeedItem
                let feedItem = ReviewFeedItem(
                    id: document.documentID,
                    spotId: spotId,
                    spotName: spotName ?? "Loading...",
                    spotAddress: spotAddress ?? "Loading...",
                    userId: userId,
                    username: username,
                    rating: value,
                    comment: comment,
                    timestamp: timestamp?.dateValue() ?? Date(),
                    chaiType: chaiType,
                    creaminessRating: creaminessRating,
                    chaiStrengthRating: chaiStrengthRating,
                    flavorNotes: flavorNotes,
                    photoURL: photoURL,
                    likes: data["likes"] as? Int ?? 0,
                    dislikes: data["dislikes"] as? Int ?? 0,
                    isRead: false,
                    visibility: data["visibility"] as? String ?? "public",
                    deleted: data["deleted"] as? Bool ?? false,
                    updatedAt: data["updatedAt"] as? Timestamp
                )
                
                return feedItem
            }
            
            print("📊 Total friend feed items created: \(feedItems.count)")
            
            // Update UI on main thread
            DispatchQueue.main.async(execute: DispatchWorkItem {
                self.isLoading = false
                self.isSwitchingFeedType = false
                self.reviews = feedItems.sorted { $0.timestamp > $1.timestamp }
                self.filteredReviews = self.reviews
                
                print("📊 Updated friend reviews array with \(self.reviews.count) items")
                
                // Validate rating data for debugging
                for feedItem in feedItems {
                    self.validateRatingData(feedItem)
                }
                
                // Load spot details asynchronously after initial load
                for feedItem in feedItems {
                    // Only fetch if we don't already have the details
                    if feedItem.spotName == "Loading..." {
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
                    } else {
                        print("✅ Skipping spot details fetch for \(feedItem.spotId) - already have: \(feedItem.spotName)")
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
                print("⚠️ FeedViewModel failed to load spot details for \(spotId) from all collections. Using fallback name: \(fallbackName)")
                completion(fallbackName, fallbackAddress)
                return
            }
            
            let collectionName = collections[currentCollectionIndex]
            currentCollectionIndex += 1
            
            print("🔍 FeedViewModel attempting to load spot \(spotId) from collection: \(collectionName)")
            
            db.collection(collectionName).document(spotId).getDocument { snapshot, error in
                DispatchQueue.main.async {
                    if let error = error {
                        // Try the next collection if this one failed
                        print("❌ FeedViewModel failed to load from collection \(collectionName): \(error.localizedDescription)")
                        tryNextCollection()
                        return
                    }
                    
                    guard let data = snapshot?.data(),
                          let name = data["name"] as? String,
                          let address = data["address"] as? String else {
                        // Data is missing, try the next collection
                        print("⚠️ FeedViewModel missing data from collection \(collectionName) for spot \(spotId)")
                        tryNextCollection()
                        return
                    }
                    
                    // Successfully loaded spot details
                    print("✅ FeedViewModel successfully loaded spot details from \(collectionName): \(name)")
                    self.loadingSpots.remove(spotId)
                    self.spotDetailsCache[spotId] = (name, address)
                    completion(name, address)
                }
            }
        }
        
        tryNextCollection()
    }
    
    // MARK: - Search and Filtering
    
    /// Checks if all spot details are loaded and ready for search
    var isSearchReady: Bool {
        return !reviews.isEmpty && !reviews.contains { $0.spotName == "Loading..." || $0.spotAddress == "Loading..." }
    }
    
    /// Gets search statistics for debugging
    func getSearchStats() -> [String: Any] {
        let totalReviews = reviews.count
        let loadedReviews = reviews.filter { $0.spotName != "Loading..." && $0.spotAddress != "Loading..." }.count
        let loadingReviews = totalReviews - loadedReviews
        
        return [
            "totalReviews": totalReviews,
            "loadedReviews": loadedReviews,
            "loadingReviews": loadingReviews,
            "searchReady": isSearchReady,
            "cacheSize": spotDetailsCache.count,
            "filteredReviewsCount": filteredReviews.count,
            "reviewsArrayIds": reviews.map { $0.id },
            "filteredReviewsArrayIds": filteredReviews.map { $0.id }
        ]
    }
    
    /// Forces refresh of spot details for better search functionality
    func forceRefreshSpotDetails() {
        print("🔄 Force refreshing spot details for \(reviews.count) reviews...")
        
        for review in reviews {
            if review.spotName == "Loading..." || review.spotAddress == "Loading..." {
                loadSpotDetails(for: review.spotId) { spotName, spotAddress in
                    DispatchQueue.main.async {
                        // Update both reviews and filteredReviews arrays
                        if let index = self.reviews.firstIndex(where: { $0.id == review.id }) {
                            self.reviews[index].spotName = spotName
                            self.reviews[index].spotAddress = spotAddress
                            
                            // Also update filteredReviews if this item is still in the filtered list
                            if let filteredIndex = self.filteredReviews.firstIndex(where: { $0.id == review.id }) {
                                self.filteredReviews[filteredIndex].spotName = spotName
                                self.filteredReviews[filteredIndex].spotAddress = spotAddress
                            }
                        }
                    }
                }
            }
        }
    }
    
    /// Handles search persistence when switching feed types
    func handleFeedTypeChange(previousFeedType: FeedType, newFeedType: FeedType, currentSearchText: String) {
        print("🔄 Feed type changed from \(previousFeedType) to \(newFeedType)")
        
        // If there's active search text, we need to re-apply the search to the new feed data
        if !currentSearchText.isEmpty {
            print("🔍 Re-applying search '\(currentSearchText)' to new feed type: \(newFeedType)")
            
            // Wait a moment for the new feed data to load, then re-apply search
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.filterReviews(currentSearchText)
            }
        }
    }
    
    /// Test method to verify search functionality
    func testSearch() {
        print("🧪 Testing search functionality...")
        print("🧪 Current reviews count: \(reviews.count)")
        print("🧪 Current filteredReviews count: \(filteredReviews.count)")
        
        // Test with a simple search
        filterReviews("test")
        print("🧪 After 'test' search - filteredReviews count: \(filteredReviews.count)")
        
        // Test with empty search
        filterReviews("")
        print("🧪 After empty search - filteredReviews count: \(filteredReviews.count)")
        
        // Test with first review's spot name
        if let firstReview = reviews.first {
            let searchTerm = String(firstReview.spotName.prefix(3))
            print("🧪 Testing search for '\(searchTerm)' (first 3 chars of '\(firstReview.spotName)')")
            filterReviews(searchTerm)
            print("🧪 After '\(searchTerm)' search - filteredReviews count: \(filteredReviews.count)")
        }
    }
    
    /// Simple test to verify UI updates
    func testUIUpdate() {
        print("🧪 Testing UI update...")
        
        // Manually set filtered reviews to first 2 reviews
        if reviews.count >= 2 {
            filteredReviews = Array(reviews.prefix(2))
            print("🧪 Manually set filteredReviews to first 2 reviews")
            print("🧪 filteredReviews count: \(filteredReviews.count)")
            
            // Force UI update
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        } else {
            print("🧪 Not enough reviews to test with")
        }
    }
    
    func filterReviews(_ searchText: String) {
        // 🆕 Cancel previous timer if it exists
        searchDebounceTimer?.invalidate()
        
        // If search text is empty, filter immediately
        if searchText.isEmpty {
            lastSearchText = searchText
            performFilterReviews(searchText)
            return
        }
        
        // 🆕 Debounce search with 300ms delay
        searchDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                self?.lastSearchText = searchText
                self?.performFilterReviews(searchText)
            }
        }
    }
    
    /// Internal function that performs the actual filtering (debounced)
    private func performFilterReviews(_ searchText: String) {
        if searchText.isEmpty {
            filteredReviews = reviews
            return
        }
        
        let searchLower = searchText.lowercased().trimmingCharacters(in: .whitespaces)
        let searchWords = searchLower.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        
        // If no valid search words, show all reviews
        if searchWords.isEmpty {
            filteredReviews = reviews
            return
        }
        
        filteredReviews = reviews.filter { review in
            // Skip reviews that are still loading spot details
            if review.spotName == "Loading..." || review.spotAddress == "Loading..." {
                return false
            }
            
            // Create comprehensive searchable text
            let locationText = review.searchableLocationText
            let reviewText = review.searchableReviewText
            let combinedText = locationText + " " + reviewText
            
            // Check if ALL search words are found in the combined text
            let allWordsFound = searchWords.allSatisfy { searchWord in
                combinedText.contains(searchWord)
            }
            
            if allWordsFound {
                return true
            }
            
            // Fallback: Check for partial matches in key fields
            let keyFields = [
                review.spotName.lowercased(),
                review.spotAddress.lowercased(),
                review.username.lowercased(),
                review.cityName.lowercased(),
                review.neighborhood.lowercased(),
                review.state.lowercased(),
                review.comment?.lowercased() ?? "",
                review.chaiType?.lowercased() ?? ""
            ]
            
            // Check if any search word matches any key field
            return searchWords.contains { searchWord in
                keyFields.contains { field in
                    field.contains(searchWord)
                }
            }
        }
        
        // Sort results by relevance (exact matches first, then partial matches)
        filteredReviews.sort { first, second in
            let firstScore = calculateSearchRelevance(first, searchWords: searchWords)
            let secondScore = calculateSearchRelevance(second, searchWords: searchWords)
            return firstScore > secondScore
        }
        
        print("🔍 Search results: Found \(filteredReviews.count) reviews for '\(searchText)'")
        print("🔍 Filtered reviews: \(filteredReviews.map { $0.spotName })")
        
        // Ensure UI updates on main thread
        DispatchQueue.main.async {
            self.objectWillChange.send()
            print("🔍 UI update: filteredReviews count = \(self.filteredReviews.count)")
        }
    }
    
    /// Calculates search relevance score for sorting results
    private func calculateSearchRelevance(_ review: ReviewFeedItem, searchWords: [String]) -> Int {
        var score = 0
        let searchText = searchWords.joined(separator: " ").lowercased()
        
        // Exact matches get highest scores
        if review.spotName.lowercased().contains(searchText) { score += 100 }
        if review.cityName.lowercased().contains(searchText) { score += 80 }
        if review.username.lowercased().contains(searchText) { score += 70 }
        if review.neighborhood.lowercased().contains(searchText) { score += 60 }
        if review.state.lowercased().contains(searchText) { score += 50 }
        if review.spotAddress.lowercased().contains(searchText) { score += 40 }
        if review.chaiType?.lowercased().contains(searchText) ?? false { score += 30 }
        if review.comment?.lowercased().contains(searchText) ?? false { score += 20 }
        
        // 🆕 Flavor notes exact matches get high priority (structured data)
        if let flavorNotes = review.flavorNotes {
            let flavorNotesText = flavorNotes.joined(separator: " ").lowercased()
            if flavorNotesText.contains(searchText) { score += 45 }
        }
        
        // Partial word matches get lower scores
        for word in searchWords {
            if review.spotName.lowercased().contains(word) { score += 10 }
            if review.cityName.lowercased().contains(word) { score += 8 }
            if review.username.lowercased().contains(word) { score += 7 }
            if review.neighborhood.lowercased().contains(word) { score += 6 }
            if review.state.lowercased().contains(word) { score += 5 }
            if review.spotAddress.lowercased().contains(word) { score += 4 }
            if review.chaiType?.lowercased().contains(word) ?? false { score += 3 }
            if review.comment?.lowercased().contains(word) ?? false { score += 2 }
            
            // 🆕 Flavor notes partial matches get higher priority than comments
            if let flavorNotes = review.flavorNotes {
                for flavorNote in flavorNotes {
                    if flavorNote.lowercased().contains(word) { score += 15 }
                }
            }
        }
        
        return score
    }
    
    /// Returns enhanced search feedback information
    func getSearchFeedback(for searchText: String) -> SearchFeedback {
        guard !searchText.isEmpty else {
            return SearchFeedback(
                resultCount: reviews.count,
                searchType: .none,
                message: "Showing all reviews"
            )
        }
        
        let searchLower = searchText.lowercased()
        var flavorNoteMatches = 0
        var locationMatches = 0
        var userMatches = 0
        
        for review in filteredReviews {
            // Check for flavor note matches
            if let flavorNotes = review.flavorNotes {
                for flavorNote in flavorNotes {
                    if flavorNote.lowercased().contains(searchLower) {
                        flavorNoteMatches += 1
                        break
                    }
                }
            }
            
            // Check for location matches
            if review.spotName.lowercased().contains(searchLower) ||
               review.cityName.lowercased().contains(searchLower) ||
               review.neighborhood.lowercased().contains(searchLower) {
                locationMatches += 1
            }
            
            // Check for user matches
            if review.username.lowercased().contains(searchLower) {
                userMatches += 1
            }
        }
        
        // Determine search type and message
        let flavorNotes = ["cardamom", "ginger", "cloves", "saffron", "fennel"]
        if flavorNotes.contains(searchLower) {
            return SearchFeedback(
                resultCount: filteredReviews.count,
                searchType: .flavorNotes,
                message: "Found \(flavorNoteMatches) reviews with \(searchText) flavor notes"
            )
        } else if locationMatches > 0 {
            return SearchFeedback(
                resultCount: filteredReviews.count,
                searchType: .location,
                message: "Found \(locationMatches) reviews in \(searchText)"
            )
        } else if userMatches > 0 {
            return SearchFeedback(
                resultCount: filteredReviews.count,
                searchType: .user,
                message: "Found \(userMatches) reviews by \(searchText)"
            )
        } else {
            return SearchFeedback(
                resultCount: filteredReviews.count,
                searchType: .general,
                message: "Found \(filteredReviews.count) results for '\(searchText)'"
            )
        }
    }
    
    // MARK: - Helper Methods
    
    /// Cleanup function to invalidate timers
    func cleanup() {
        searchDebounceTimer?.invalidate()
        searchDebounceTimer = nil
        reactionUpdateTimer?.invalidate()
        reactionUpdateTimer = nil
    }
    
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