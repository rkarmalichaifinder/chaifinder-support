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
                        guard let data = document.data() as? [String: Any],
                              let spotId = data["spotId"] as? String,
                              let userId = data["userId"] as? String,
                              let value = data["value"] as? Int else {
                            return nil
                        }
                        
                        let username = data["username"] as? String
                        let comment = data["comment"] as? String
                        let timestamp = data["timestamp"] as? Timestamp
                        let likes = data["likes"] as? Int
                        let dislikes = data["dislikes"] as? Int
                        let creaminessRating = data["creaminessRating"] as? Int
                        let chaiStrengthRating = data["chaiStrengthRating"] as? Int
                        let flavorNotes = data["flavorNotes"] as? [String]
                        
                        return Rating(
                            spotId: spotId,
                            userId: userId,
                            username: username,
                            value: value,
                            comment: comment,
                            timestamp: timestamp?.dateValue(),
                            likes: likes,
                            dislikes: dislikes,
                            creaminessRating: creaminessRating,
                            chaiStrengthRating: chaiStrengthRating,
                            flavorNotes: flavorNotes
                        )
                    }
                }
            }
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
            // Try both collections - chaiFinder and chaiSpots
            let collections = ["chaiFinder", "chaiSpots"]
            var currentCollectionIndex = 0
            
            func tryNextCollection() {
                guard currentCollectionIndex < collections.count else {
                    // All collections failed, use fallback
                    let fallbackName = "Chai Spot #\(spotId.prefix(6))"
                    let fallbackAddress = "Tap to view details"
                    self.spotDetailsCache[spotId] = (fallbackName, fallbackAddress)
                    
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
                
                db.collection(collectionName).document(spotId).getDocument { snapshot, error in
                DispatchQueue.main.async {
                    self.loadingSpots.remove(spotId)
                    
                    if let error = error {
                        // Try the next collection if this one failed
                        print("Failed to load from collection \(collections[currentCollectionIndex - 1]): \(error.localizedDescription)")
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
                        print("Missing data from collection \(collections[currentCollectionIndex - 1])")
                        tryNextCollection()
                        return
                    }
                    
                    let averageRating = data["averageRating"] as? Double ?? 0.0
                    let ratingCount = data["ratingCount"] as? Int ?? 0
                    
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
        
        attemptLoad()
    }
}

struct FriendRatingCard: View {
    let rating: Rating
    let onTap: () -> Void
    @State private var spotName = "Loading..."
    @State private var spotAddress = "Loading..."
    @State private var isLoading = false
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(spotName)
                            .font(DesignSystem.Typography.bodyLarge)
                            .fontWeight(.semibold)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                            .lineLimit(1)
                        
                        Text(spotAddress)
                            .font(DesignSystem.Typography.bodySmall)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
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
        .onAppear {
            loadSpotDetails()
        }
    }
    
    private func loadSpotDetails() {
        // Load spot details from cache or fetch them
        let db = Firestore.firestore()
        
        // Try both collections
        let collections = ["chaiFinder", "chaiSpots"]
        var currentCollectionIndex = 0
        
        func tryNextCollection() {
            guard currentCollectionIndex < collections.count else {
                // All collections failed, use fallback
                spotName = "Unknown Spot"
                spotAddress = "Tap to view details"
                return
            }
            
            let collectionName = collections[currentCollectionIndex]
            currentCollectionIndex += 1
            
            db.collection(collectionName).document(rating.spotId).getDocument { snapshot, error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("Failed to load from collection \(collectionName): \(error.localizedDescription)")
                        tryNextCollection()
                        return
                    }
                    
                    guard let data = snapshot?.data(),
                          let name = data["name"] as? String,
                          let address = data["address"] as? String else {
                        print("Missing data from collection \(collectionName)")
                        tryNextCollection()
                        return
                    }
                    
                    // Successfully loaded spot details
                    spotName = name
                    spotAddress = address
                }
            }
        }
        
        tryNextCollection()
    }
}

} 