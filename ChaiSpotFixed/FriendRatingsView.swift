import SwiftUI
import Firebase
import FirebaseFirestore

struct FriendRatingsView: View {
    let friend: UserProfile
    @Environment(\.dismiss) private var dismiss
    @State private var friendRatings: [Rating] = []
    @State private var isLoading = false
    @State private var error: String?
    @State private var selectedSpot: ChaiSpot?
    @State private var spotDetailsCache: [String: (name: String, address: String)] = [:]
    @State private var loadingSpots: Set<String> = []
    
    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.Colors.background
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: DesignSystem.Spacing.md) {
                        HStack {
                            // Friend Avatar
                            let initials = friend.displayName
                                .split(separator: " ")
                                .compactMap { $0.first }
                                .prefix(2)
                                .map { String($0) }
                                .joined()
                            
                            Text(initials.uppercased())
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 50, height: 50)
                                .background(DesignSystem.Colors.primary)
                                .clipShape(Circle())
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(friend.displayName)
                                    .font(DesignSystem.Typography.headline)
                                    .fontWeight(.bold)
                                    .foregroundColor(DesignSystem.Colors.textPrimary)
                                
                                Text("\(friendRatings.count) ratings")
                                    .font(DesignSystem.Typography.bodyMedium)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                            }
                            
                            Spacer()
                        }
                        .padding(DesignSystem.Spacing.lg)
                    }
                    .background(DesignSystem.Colors.cardBackground)
                    
                    // Content
                    if isLoading {
                        VStack(spacing: DesignSystem.Spacing.lg) {
                            Spacer()
                            ProgressView()
                                .scaleEffect(1.2)
                            Text("Loading \(friend.displayName)'s ratings...")
                                .font(DesignSystem.Typography.bodyLarge)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if friendRatings.isEmpty {
                        VStack(spacing: DesignSystem.Spacing.lg) {
                            Spacer()
                            Image(systemName: "cup.and.saucer")
                                .font(.system(size: 48))
                                .foregroundColor(DesignSystem.Colors.secondary)
                            
                            Text("No Ratings Yet")
                                .font(DesignSystem.Typography.headline)
                                .fontWeight(.bold)
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                            
                            Text("\(friend.displayName) hasn't rated any chai spots yet")
                                .font(DesignSystem.Typography.bodyMedium)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                                .multilineTextAlignment(.center)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(DesignSystem.Spacing.xl)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: DesignSystem.Spacing.md) {
                                ForEach(friendRatings) { rating in
                                    FriendRatingCard(
                                        rating: rating,
                                        onTap: {
                                            loadSpotDetails(for: rating.spotId) { spot in
                                                selectedSpot = spot
                                            }
                                        }
                                    )
                                }
                            }
                            .padding(DesignSystem.Spacing.lg)
                        }
                        .refreshable {
                            loadFriendRatings()
                        }
                    }
                    
                    Spacer(minLength: 0)
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                loadFriendRatings()
            }
            .sheet(item: $selectedSpot) { spot in
                ChaiSpotDetailSheet(spot: spot, userLocation: nil)
            }
        }
    }
    
    private func loadFriendRatings() {
        isLoading = true
        error = nil
        
        let db = Firestore.firestore()
        
        db.collection("ratings")
            .whereField("userId", isEqualTo: friend.uid)
            .order(by: "timestamp", descending: true)
            .getDocuments { snapshot, error in
                DispatchQueue.main.async {
                    self.isLoading = false
                    
                    if let error = error {
                        self.error = error.localizedDescription
                        return
                    }
                    
                    guard let documents = snapshot?.documents else {
                        self.friendRatings = []
                        return
                    }
                    
                    self.friendRatings = documents.compactMap { document -> Rating? in
                        let data = document.data()
                        
                        guard let spotId = data["spotId"] as? String,
                              let userId = data["userId"] as? String else {
                            print("⚠️ FriendRatingsView: Invalid rating document: \(document.documentID)")
                            print("🔍 Debug info: data keys: \(Array(data.keys))")
                            print("🔍 Debug info: spotId type: \(type(of: data["spotId"] ?? "nil")), userId type: \(type(of: data["userId"] ?? "nil"))")
                            return nil
                        }
                        
                        // 🔧 FIX: Use the correct field name "value" instead of "rating"
                        guard let rating = data["value"] as? Int else {
                            print("❌ FriendRatingsView: Rating \(document.documentID) missing or invalid value field")
                            print("🔍 Available fields: \(Array(data.keys))")
                            print("🔍 Value field value: \(data["value"] ?? "nil")")
                            return nil
                        }
                        
                        // 🔧 FIX: Validate rating value is within expected range
                        guard rating >= 1 && rating <= 5 else {
                            print("❌ FriendRatingsView: Rating \(document.documentID) has invalid value: \(rating) (should be 1-5)")
                            return nil
                        }
                        
                        // 🔧 FIX: Clamp rating to valid range instead of rejecting
                        let clampedRating = max(1, min(5, rating))
                        if clampedRating != rating {
                            print("⚠️ FriendRatingsView: Rating \(document.documentID) value \(rating) clamped to \(clampedRating)")
                        }
                        
                        print("🔍 FriendRatingsView: Processing rating for spotId: '\(spotId)', userId: '\(userId)', rating: \(rating)")
                        print("🔍 FriendRatingsView: Available fields: \(Array(data.keys))")
                        
                        let username = data["username"] as? String
                        let comment = data["comment"] as? String
                        let timestamp = data["timestamp"] as? Timestamp
                        let likes = data["likes"] as? Int
                        let dislikes = data["dislikes"] as? Int
                        let creaminessRating = data["creaminessRating"] as? Int
                        let chaiStrengthRating = data["chaiStrengthRating"] as? Int
                        let flavorNotes = data["flavorNotes"] as? [String]
                        let spotName = data["spotName"] as? String
                        let spotAddress = data["spotAddress"] as? String
                        let chaiType = data["chaiType"] as? String
                        let photoURL = data["photoURL"] as? String
                        let hasPhoto = data["hasPhoto"] as? Bool ?? false
                        let gamificationScore = data["gamificationScore"] as? Int ?? 0
                        let visibility = data["visibility"] as? String ?? "public"
                        
                        print("🔍 FriendRatingsView: Found spotName in rating: \(spotName ?? "nil")")
                        
                        return Rating(
                            spotId: spotId,
                            userId: userId,
                            username: username,
                            spotName: spotName, // Use the spotName from the rating document
                            value: rating,
                            comment: comment,
                            timestamp: timestamp?.dateValue(),
                            likes: likes,
                            dislikes: dislikes,
                            creaminessRating: creaminessRating,
                            chaiStrengthRating: chaiStrengthRating,
                            flavorNotes: flavorNotes,
                            chaiType: chaiType,
                            photoURL: photoURL,
                            hasPhoto: hasPhoto,
                            reactions: [:],
                            isStreakReview: false,
                            gamificationScore: gamificationScore,
                            isFirstReview: false,
                            isNewSpot: false,
                            visibility: visibility
                        )
                    }
                    
                    print("✅ FriendRatingsView: Loaded \(self.friendRatings.count) ratings")
                    for rating in self.friendRatings {
                        print("🔍 Rating: spotId='\(rating.spotId)', value=\(rating.value), spotName='\(rating.spotName ?? "nil")'")
                    }
                    
                    // Load spot names for ratings that don't have them
                    self.loadMissingSpotNames()
                }
            }
    }
    
    // MARK: - Load Missing Spot Names
    
    private func loadMissingSpotNames() {
        let db = Firestore.firestore()
        let collections = ["chaiFinder"] // Only use chaiFinder since chaiSpots has permission issues
        
        // Only load spot names for ratings that don't already have them
        for (index, rating) in friendRatings.enumerated() {
            if rating.spotName == nil || rating.spotName?.isEmpty == true {
                print("🔍 Loading missing spot name for rating \(index), spotId: \(rating.spotId)")
                loadSpotNameForRating(rating, at: index, from: collections)
            } else {
                print("✅ Rating \(index) already has spot name: \(rating.spotName ?? "nil")")
            }
        }
    }
    
    private func loadSpotNameForRating(_ rating: Rating, at index: Int, from collections: [String]) {
        let db = Firestore.firestore()
        
        // Since we only use chaiFinder now, simplify the logic
        let collectionName = "chaiFinder"
        print("🔍 Loading spot name for rating \(index) from collection: \(collectionName), spotId: \(rating.spotId)")
        
        db.collection(collectionName).document(rating.spotId).getDocument { snapshot, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Failed to load from collection \(collectionName) for rating \(index): \(error.localizedDescription)")
                    // Use fallback
                    let fallbackName = "Chai Spot #\(rating.spotId.prefix(6))"
                    print("⚠️ Failed to load spot name for rating \(index), using fallback: \(fallbackName)")
                    
                    if index < self.friendRatings.count {
                        self.friendRatings[index].spotName = fallbackName
                    }
                    return
                }
                
                guard let data = snapshot?.data() else {
                    print("⚠️ No data found in collection \(collectionName) for rating \(index), spotId: \(rating.spotId)")
                    // Use fallback
                    let fallbackName = "Chai Spot #\(rating.spotId.prefix(6))"
                    print("⚠️ Failed to load spot name for rating \(index), using fallback: \(fallbackName)")
                    
                    if index < self.friendRatings.count {
                        self.friendRatings[index].spotName = fallbackName
                    }
                    return
                }
                
                guard let name = data["name"] as? String, !name.isEmpty else {
                    print("⚠️ Missing or empty name from collection \(collectionName) for rating \(index)")
                    print("🔍 Available fields: \(Array(data.keys))")
                    // Use fallback
                    let fallbackName = "Chai Spot #\(rating.spotId.prefix(6))"
                    print("⚠️ Failed to load spot name for rating \(index), using fallback: \(fallbackName)")
                    
                    if index < self.friendRatings.count {
                        self.friendRatings[index].spotName = fallbackName
                    }
                    return
                }
                
                print("✅ Successfully loaded spot name for rating \(index): \(name)")
                
                if index < self.friendRatings.count {
                    self.friendRatings[index].spotName = name
                }
            }
        }
    }
    

    
    // MARK: - Debug Collections
    private func debugCollections() {
        let db = Firestore.firestore()
        let collections = ["chaiFinder"] // Only check chaiFinder since chaiSpots has permission issues
        
        for collectionName in collections {
            db.collection(collectionName).getDocuments { snapshot, error in
                if let error = error {
                    print("❌ Debug: Failed to load collection \(collectionName): \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("⚠️ Debug: No documents in collection \(collectionName)")
                    return
                }
                
                print("🔍 Debug: Collection \(collectionName) has \(documents.count) documents")
                
                // Show first few document IDs and names
                for (index, document) in documents.prefix(5).enumerated() {
                    let data = document.data()
                    let name = data["name"] as? String ?? "No name"
                    print("🔍 Debug: \(collectionName)[\(index)]: ID=\(document.documentID), Name=\(name)")
                }
                
                if documents.count > 5 {
                    print("🔍 Debug: ... and \(documents.count - 5) more documents")
                }
            }
        }
    }
    
    // MARK: - Debug Rating Data
    private func debugRatingData() {
        guard !friendRatings.isEmpty else {
            print("🔍 Debug: No ratings to debug")
            return
        }
        
        print("🔍 Debug: Analyzing first rating document...")
        
        let db = Firestore.firestore()
        db.collection("ratings")
            .whereField("userId", isEqualTo: friend.uid)
            .order(by: "timestamp", descending: true)
            .limit(to: 3) // Get first 3 documents
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ Debug: Failed to load rating documents: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("⚠️ Debug: No rating documents found")
                    return
                }
                
                print("🔍 Debug: Found \(documents.count) rating documents")
                
                for (index, document) in documents.enumerated() {
                    let data = document.data()
                    print("🔍 Debug: Document \(index) - ID: \(document.documentID)")
                    print("  - spotId: \(data["spotId"] ?? "nil")")
                    print("  - userId: \(data["userId"] ?? "nil")")
                    print("  - rating: \(data["rating"] ?? "nil") (type: \(type(of: data["rating"] ?? "nil")))")
                    print("  - spotName: \(data["spotName"] ?? "nil")")
                    print("  - Available fields: \(Array(data.keys))")
                    
                    // Check if rating is actually 0 or missing
                    if let ratingValue = data["rating"] {
                        if let intValue = ratingValue as? Int {
                            print("  - Rating as Int: \(intValue)")
                        } else if let doubleValue = ratingValue as? Double {
                            print("  - Rating as Double: \(doubleValue)")
                        } else {
                            print("  - Rating as other type: \(ratingValue)")
                        }
                    } else {
                        print("  - Rating field is missing!")
                    }
                }
            }
    }
    
    // MARK: - Debug Recent Ratings
    private func debugRecentRatings() {
        print("🔍 Debug: Checking recent ratings for spotName field...")
        
        let db = Firestore.firestore()
        db.collection("ratings")
            .order(by: "timestamp", descending: true)
            .limit(to: 5) // Get 5 most recent ratings
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ Debug: Failed to load recent ratings: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("⚠️ Debug: No recent rating documents found")
                    return
                }
                
                print("🔍 Debug: Found \(documents.count) recent rating documents")
                
                for (index, document) in documents.enumerated() {
                    let data = document.data()
                    let spotName = data["spotName"] as? String
                    let spotId = data["spotId"] as? String
                    let userId = data["userId"] as? String
                    
                    print("🔍 Debug: Recent rating \(index + 1):")
                    print("  - Document ID: \(document.documentID)")
                    print("  - User ID: \(userId ?? "nil")")
                    print("  - Spot ID: \(spotId ?? "nil")")
                    print("  - Spot Name: \(spotName ?? "nil")")
                    
                    if spotName == nil || spotName?.isEmpty == true {
                        print("  ⚠️ WARNING: This rating has no spotName!")
                    } else {
                        print("  ✅ This rating has spotName: \(spotName!)")
                    }
                    print("---")
                }
            }
    }
    
    // MARK: - Enhanced Spot Search
    private func enhancedSpotSearch(for spotId: String, completion: @escaping (String, String) -> Void) {
        let db = Firestore.firestore()
        let collections = ["chaiFinder"] // Only use chaiFinder since chaiSpots has permission issues
        
        // First, try to find any rating that might reference this spot
        db.collection("ratings")
            .whereField("spotId", isEqualTo: spotId)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ Enhanced search: Failed to search ratings: \(error.localizedDescription)")
                    completion("Chai Spot (Details Unavailable)", "Location information not found")
                    return
                }
                
                guard let documents = snapshot?.documents, !documents.isEmpty else {
                    print("⚠️ Enhanced search: No ratings found for spotId: \(spotId)")
                    completion("Chai Spot (Details Unavailable)", "Location information not found")
                    return
                }
                
                // Look for any rating that might have additional spot information
                for document in documents {
                    let data = document.data()
                    if let spotName = data["spotName"] as? String, !spotName.isEmpty {
                        let address = data["spotAddress"] as? String ?? "Address not available"
                        print("✅ Enhanced search: Found spot name from rating: \(spotName)")
                        completion(spotName, address)
                        return
                    }
                }
                
                // If no spot name in ratings, try collections
                self.searchCollectionsForSpot(spotId: spotId, collections: collections, completion: completion)
            }
    }
    
    private func searchCollectionsForSpot(spotId: String, collections: [String], completion: @escaping (String, String) -> Void) {
        var currentIndex = 0
        
        func tryNextCollection() {
            guard currentIndex < collections.count else {
                completion("Chai Spot (Details Unavailable)", "Location information not found")
                return
            }
            
            let collectionName = collections[currentIndex]
            currentIndex += 1
            
            let db = Firestore.firestore()
            db.collection(collectionName).document(spotId).getDocument { snapshot, error in
                if let error = error {
                    print("❌ Enhanced search: Failed to load from \(collectionName): \(error.localizedDescription)")
                    tryNextCollection()
                    return
                }
                
                guard let data = snapshot?.data(),
                      let name = data["name"] as? String,
                      let address = data["address"] as? String else {
                    print("⚠️ Enhanced search: Missing data from \(collectionName)")
                    tryNextCollection()
                    return
                }
                
                print("✅ Enhanced search: Found spot in \(collectionName): \(name)")
                completion(name, address)
            }
        }
        
        tryNextCollection()
    }
    
    private func loadSpotDetails(for spotId: String, completion: @escaping (ChaiSpot) -> Void) {
        // Check cache first
        if let cached = spotDetailsCache[spotId] {
            let spot = ChaiSpot(
                id: spotId,
                name: cached.name,
                address: cached.address,
                latitude: 0.0, // Default values since we don't have them cached
                longitude: 0.0,
                chaiTypes: [],
                averageRating: 0.0,
                ratingCount: 0
            )
            completion(spot)
            return
        }
        
        // Prevent duplicate requests
        if loadingSpots.contains(spotId) {
            return
        }
        
        loadingSpots.insert(spotId)
        
        let db = Firestore.firestore()
        
        // Add retry logic for permission issues
        func attemptLoad(retryCount: Int = 0) {
            // Only use chaiFinder since chaiSpots has permission issues
            let collections = ["chaiFinder"]
            var currentCollectionIndex = 0
            
            func tryNextCollection() {
                guard currentCollectionIndex < collections.count else {
                    // All collections failed, use fallback
                    let fallbackName = "Chai Spot #\(spotId.prefix(6))"
                    let fallbackAddress = "Location details unavailable"
                    self.spotDetailsCache[spotId] = (fallbackName, fallbackAddress)
                    
                    print("⚠️ Failed to load spot details for \(spotId) from all collections. Using fallback name: \(fallbackName)")
                    
                    let spot = ChaiSpot(
                        id: spotId,
                        name: fallbackName,
                        address: fallbackAddress,
                        latitude: 0.0,
                        longitude: 0.0,
                        chaiTypes: [],
                        averageRating: 0.0,
                        ratingCount: 0
                    )
                    completion(spot)
                    return
                }
                
                let collectionName = collections[currentCollectionIndex]
                currentCollectionIndex += 1
                
                print("🔍 Attempting to load spot \(spotId) from collection: \(collectionName)")
                
                db.collection(collectionName).document(spotId).getDocument { snapshot, error in
                    DispatchQueue.main.async {
                        self.loadingSpots.remove(spotId)
                        
                        if let error = error {
                            // Try the next collection if this one failed
                            print("❌ Failed to load from collection \(collections[currentCollectionIndex - 1]): \(error.localizedDescription)")
                            tryNextCollection()
                            return
                        }
                        
                        guard let data = snapshot?.data(),
                              let name = data["name"] as? String,
                              let address = data["address"] as? String,
                              let latitude = data["latitude"] as? Double,
                              let longitude = data["longitude"] as? Double,
                              let chaiTypes = data["chaiTypes"] as? [String] else {
                            // Data is missing, try the next collection
                            print("⚠️ Missing data from collection \(collections[currentCollectionIndex - 1]) for spot \(spotId)")
                            tryNextCollection()
                            return
                        }
                        
                        let averageRating = data["averageRating"] as? Double ?? 0.0
                        let ratingCount = data["ratingCount"] as? Int ?? 0
                        
                        print("✅ Successfully loaded spot details from \(collectionName): \(name)")
                        
                        self.spotDetailsCache[spotId] = (name, address)
                        
                        let spot = ChaiSpot(
                            id: spotId,
                            name: name,
                            address: address,
                            latitude: latitude,
                            longitude: longitude,
                            chaiTypes: chaiTypes,
                            averageRating: averageRating,
                            ratingCount: ratingCount
                        )
                        
                        completion(spot)
                    }
                }
            }
        }
        
        attemptLoad()
    }
    
    // MARK: - Data Fix Functions
    
    /// Fixes invalid rating values in the database
    func fixInvalidRatings(completion: @escaping (Error?) -> Void) {
        print("🔧 Starting to fix invalid ratings...")
        let db = Firestore.firestore()
        var lastDoc: DocumentSnapshot?
        var totalProcessed = 0
        var totalFixed = 0
        
        func processBatch() {
            var query: Query = db.collection("ratings")
                .order(by: FieldPath.documentID())
                .limit(to: 100)
            
            if let last = lastDoc {
                query = query.start(afterDocument: last)
            }
            
            query.getDocuments { snapshot, error in
                if let error = error {
                    print("❌ Error processing batch: \(error.localizedDescription)")
                    completion(error)
                    return
                }
                
                guard let snapshot = snapshot, !snapshot.documents.isEmpty else {
                    print("✅ Fix completed! Total processed: \(totalProcessed), Total fixed: \(totalFixed)")
                    completion(nil)
                    return
                }
                
                let batch = db.batch()
                var batchFixed = 0
                
                for doc in snapshot.documents {
                    let data = doc.data()
                    var needsUpdate = false
                    var patch: [String: Any] = [:]
                    
                    // Check for invalid rating values
                    if let ratingValue = data["rating"] {
                        if let intValue = ratingValue as? Int {
                            if intValue < 1 || intValue > 5 {
                                print("🔧 Fixing invalid rating value: \(intValue) -> 3")
                                patch["rating"] = 3
                                needsUpdate = true
                            }
                        } else if let doubleValue = ratingValue as? Double {
                            let intValue = Int(doubleValue)
                            if intValue < 1 || intValue > 5 {
                                print("🔧 Fixing invalid rating value: \(doubleValue) -> 3")
                                patch["rating"] = 3
                                needsUpdate = true
                            } else if doubleValue != Double(intValue) {
                                print("🔧 Converting Double to Int: \(doubleValue) -> \(intValue)")
                                patch["rating"] = intValue
                                needsUpdate = true
                            }
                        } else if let stringValue = ratingValue as? String, let intValue = Int(stringValue) {
                            if intValue < 1 || intValue > 5 {
                                print("🔧 Fixing invalid rating value: \(stringValue) -> 3")
                                patch["rating"] = 3
                                needsUpdate = true
                            } else {
                                print("🔧 Converting String to Int: \(stringValue) -> \(intValue)")
                                patch["rating"] = intValue
                                needsUpdate = true
                            }
                        } else {
                            print("🔧 Setting missing/invalid rating to default: 3")
                            patch["rating"] = 3
                            needsUpdate = true
                        }
                    } else {
                        print("🔧 Adding missing rating field with default: 3")
                        patch["rating"] = 3
                        needsUpdate = true
                    }
                    
                    if needsUpdate {
                        batch.updateData(patch, forDocument: doc.reference)
                        batchFixed += 1
                    }
                }
                
                if batchFixed > 0 {
                    batch.commit { batchError in
                        if let batchError = batchError {
                            print("❌ Batch commit error: \(batchError.localizedDescription)")
                            completion(batchError)
                            return
                        }
                        
                        totalProcessed += snapshot.documents.count
                        totalFixed += batchFixed
                        print("🔄 Processed batch: \(snapshot.documents.count) docs, fixed: \(batchFixed). Total: \(totalProcessed)/\(totalFixed)")
                        
                        lastDoc = snapshot.documents.last
                        processBatch()
                    }
                } else {
                    totalProcessed += snapshot.documents.count
                    lastDoc = snapshot.documents.last
                    processBatch()
                }
            }
        }
        
        processBatch()
    }
}

struct FriendRatingCard: View {
    let rating: Rating
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(rating.spotName ?? "Loading spot name...")
                            .font(DesignSystem.Typography.bodyLarge)
                            .fontWeight(.semibold)
                            .foregroundColor(rating.spotName == nil ? DesignSystem.Colors.textSecondary : DesignSystem.Colors.textPrimary)
                            .lineLimit(1)
                        
                        Text(rating.spotName == nil ? "Loading..." : "Tap to view details")
                            .font(DesignSystem.Typography.bodySmall)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    // 🔧 DEBUG: Add debugging for rating value display
                    Text("\(rating.value)★")
                        .font(DesignSystem.Typography.titleMedium)
                        .fontWeight(.bold)
                        .foregroundColor(DesignSystem.Colors.primary)
                }
                
                // Display rating fields - always show with "NR" if missing
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    // Creaminess Rating
                    HStack {
                        Image(systemName: "drop.fill")
                            .foregroundColor(DesignSystem.Colors.creaminessRating)
                            .font(.caption)
                        if let creaminessRating = rating.creaminessRating {
                            Text("Creaminess: \(creaminessRating)/5")
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        } else {
                            Text("Creaminess: NR")
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                                .italic()
                        }
                    }
                    
                    // Chai Strength Rating
                    HStack {
                        Image(systemName: "flame.fill")
                            .foregroundColor(DesignSystem.Colors.chaiStrengthRating)
                            .font(.caption)
                        if let chaiStrengthRating = rating.chaiStrengthRating {
                            Text("Strength: \(chaiStrengthRating)/5")
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        } else {
                            Text("Strength: NR")
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                                .italic()
                        }
                    }
                    
                    // Flavor Notes
                    if let flavorNotes = rating.flavorNotes, !flavorNotes.isEmpty {
                        HStack {
                            Image(systemName: "leaf.fill")
                                .foregroundColor(DesignSystem.Colors.flavorNotesRating)
                                .font(.caption)
                            Text("Notes: \(flavorNotes.joined(separator: ", "))")
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                                .lineLimit(2)
                        }
                    }
                }
                
                // 🎮 NEW: Photo Display
                if let photoURL = rating.photoURL, !photoURL.isEmpty {
                    VStack(spacing: 4) {
                        CachedAsyncImage(url: photoURL, cornerRadius: 8)
                            .frame(height: 120)
                        
                        // Photo bonus indicator
                        HStack(spacing: 3) {
                            Image(systemName: "camera.fill")
                                .foregroundColor(.orange)
                                .font(.caption2)
                            
                            Text("Photo included (+15 points)")
                                .font(DesignSystem.Typography.caption2)
                                .foregroundColor(.orange)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(4)
                    }
                    .padding(.vertical, 4)
                }
                
                // Comment
                if let comment = rating.comment, !comment.isEmpty {
                    Text(comment)
                        .font(DesignSystem.Typography.bodySmall)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .lineLimit(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(DesignSystem.Spacing.md)
            .background(DesignSystem.Colors.cardBackground)
            .cornerRadius(DesignSystem.CornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                    .stroke(DesignSystem.Colors.border, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}