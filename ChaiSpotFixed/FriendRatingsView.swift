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
    @State private var showingSpotDetail = false
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
                                                showingSpotDetail = true
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
            .sheet(isPresented: $showingSpotDetail) {
                if let spot = selectedSpot {
                    ChaiSpotDetailSheet(spot: spot, userLocation: nil)
                }
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
                        
                        return Rating(
                            spotId: spotId,
                            userId: userId,
                            username: username,
                            value: value,
                            comment: comment,
                            timestamp: timestamp?.dateValue(),
                            likes: likes,
                            dislikes: dislikes
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
                    
                    guard let data = snapshot?.data(),
                          let name = data["name"] as? String,
                          let address = data["address"] as? String,
                          let latitude = data["latitude"] as? Double,
                          let longitude = data["longitude"] as? Double,
                          let chaiTypes = data["chaiTypes"] as? [String] else {
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
                
                if let comment = rating.comment, !comment.isEmpty {
                    Text(comment)
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .lineLimit(3)
                }
                
                if let timestamp = rating.timestamp {
                    Text(timestamp, style: .relative)
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
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
            if !isLoading && (spotName == "Loading..." || spotAddress == "Loading...") {
                loadSpotDetails()
            }
        }
    }
    
    private func loadSpotDetails() {
        guard !isLoading else { return }
        isLoading = true
        
        let db = Firestore.firestore()
        
        // Add retry logic for permission issues
        func attemptLoad(retryCount: Int = 0) {
            db.collection("chaiFinder").document(rating.spotId).getDocument { snapshot, error in
                DispatchQueue.main.async {
                    self.isLoading = false
                    
                    if let error = error {
                        // Retry once for permission issues
                        if retryCount == 0 && error.localizedDescription.contains("permissions") {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                attemptLoad(retryCount: 1)
                            }
                            return
                        }
                        
                        self.spotName = "Chai Spot #\(self.rating.spotId.prefix(6))"
                        self.spotAddress = "Tap to view details"
                        return
                    }
                    
                    guard let data = snapshot?.data(),
                          let name = data["name"] as? String,
                          let address = data["address"] as? String else {
                        self.spotName = "Chai Spot #\(self.rating.spotId.prefix(6))"
                        self.spotAddress = "Tap to view details"
                        return
                    }
                    
                    self.spotName = name
                    self.spotAddress = address
                }
            }
        }
        
        attemptLoad()
    }
} 