import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct UserTopSpotsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var sessionStore: SessionStore
    
    @State private var topSpots: [TopSpotItem] = []
    @State private var isLoading = false
    @State private var error: String?
    
    private let db = Firestore.firestore()
    
    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.Colors.background
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: DesignSystem.Spacing.md) {
                        HStack {
                            Text("Top Spots")
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            Spacer()
                            
                            Button("Done") {
                                dismiss()
                            }
                            .font(DesignSystem.Typography.bodyMedium)
                            .foregroundColor(DesignSystem.Colors.primary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Text("chai finder")
                            .font(DesignSystem.Typography.titleLarge)
                            .fontWeight(.bold)
                            .foregroundColor(DesignSystem.Colors.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(DesignSystem.Spacing.lg)
                    .background(DesignSystem.Colors.background)
                    .iPadOptimized()
                    
                    if isLoading {
                        VStack(spacing: DesignSystem.Spacing.lg) {
                            ProgressView()
                                .scaleEffect(UIDevice.current.userInterfaceIdiom == .pad ? 1.5 : 1.2)
                            Text("Loading your top spots...")
                                .font(DesignSystem.Typography.bodyLarge)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .iPadOptimized()
                    } else if let error = error {
                        VStack(spacing: DesignSystem.Spacing.lg) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: UIDevice.current.userInterfaceIdiom == .pad ? 64 : 48))
                                .foregroundColor(DesignSystem.Colors.secondary)
                            
                            Text("Error")
                                .font(DesignSystem.Typography.headline)
                                .fontWeight(.bold)
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                            
                            Text(error)
                                .font(DesignSystem.Typography.bodyMedium)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(DesignSystem.Spacing.xl)
                        .iPadOptimized()
                    } else if topSpots.isEmpty {
                        VStack(spacing: DesignSystem.Spacing.lg) {
                            Image(systemName: "star.circle")
                                .font(.system(size: UIDevice.current.userInterfaceIdiom == .pad ? 64 : 48))
                                .foregroundColor(DesignSystem.Colors.secondary)
                            
                            Text("No Top Spots Yet")
                                .font(DesignSystem.Typography.headline)
                                .fontWeight(.bold)
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                            
                            Text("Start rating chai spots to see your favorites here!")
                                .font(DesignSystem.Typography.bodyMedium)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(DesignSystem.Spacing.xl)
                        .iPadOptimized()
                    } else {
                        ScrollView {
                            VStack(spacing: DesignSystem.Spacing.lg) {
                                ForEach(Array(topSpots.enumerated()), id: \.element.id) { index, spot in
                                    TopSpotCard(
                                        spot: spot,
                                        rank: index + 1
                                    )
                                }
                            }
                            .padding(DesignSystem.Spacing.lg)
                            .iPadOptimized()
                        }
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
        .onAppear {
            loadUserTopSpots()
        }
    }
    
    private func loadUserTopSpots() {
        guard let userId = Auth.auth().currentUser?.uid else {
            error = "Please log in to view your top spots"
            return
        }
        
        isLoading = true
        error = nil
        
        // First, get all user ratings with 5 stars
        db.collection("ratings")
            .whereField("userId", isEqualTo: userId)
            .whereField("rating", isEqualTo: 5)
            .getDocuments { snapshot, error in
                DispatchQueue.main.async {
                    if let error = error {
                        self.isLoading = false
                        self.error = "Failed to load ratings: \(error.localizedDescription)"
                        return
                    }
                    
                    guard let documents = snapshot?.documents, !documents.isEmpty else {
                        self.isLoading = false
                        self.topSpots = []
                        return
                    }
                    
                    // Get unique spot IDs from 5-star ratings
                    let spotIds = Array(Set(documents.compactMap { $0.data()["spotId"] as? String }))
                    
                    if spotIds.isEmpty {
                        self.isLoading = false
                        self.topSpots = []
                        return
                    }
                    
                    // Now get community scores for these spots
                    self.loadCommunityScores(for: spotIds)
                }
            }
    }
    
    private func loadCommunityScores(for spotIds: [String]) {
        let batchSize = 10 // Firestore limit for 'in' queries
        var allSpots: [TopSpotItem] = []
        var processedCount = 0
        
        func processBatch(_ batchSpotIds: [String]) {
            db.collection("ratings")
                .whereField("spotId", in: batchSpotIds)
                .getDocuments { snapshot, error in
                    DispatchQueue.main.async {
                        if let error = error {
                            self.isLoading = false
                            self.error = "Failed to load community scores: \(error.localizedDescription)"
                            return
                        }
                        
                        guard let documents = snapshot?.documents else {
                            self.isLoading = false
                            self.topSpots = []
                            return
                        }
                        
                        // Group ratings by spotId and collect spot details
                        var spotRatings: [String: [Rating]] = [:]
                        var spotDetails: [String: (name: String, address: String)] = [:]
                        
                        for document in documents {
                            let data = document.data()
                            if let spotId = data["spotId"] as? String,
                               let ratingValue = data["rating"] as? Int {
                                let rating = Rating(
                                    spotId: spotId,
                                    userId: data["userId"] as? String ?? "",
                                    value: ratingValue,
                                    comment: data["comment"] as? String,
                                    timestamp: (data["timestamp"] as? Timestamp)?.dateValue()
                                )
                                spotRatings[spotId, default: []].append(rating)
                                
                                // Store spot details
                                if spotDetails[spotId] == nil {
                                    let spotName = data["spotName"] as? String ?? "Unknown Location"
                                    let spotAddress = data["spotAddress"] as? String ?? "Address not available"
                                    spotDetails[spotId] = (name: spotName, address: spotAddress)
                                }
                            }
                        }
                        
                        // Calculate average community scores
                        for (spotId, ratings) in spotRatings {
                            let communityRatings = ratings.filter { $0.userId != Auth.auth().currentUser?.uid }
                            if !communityRatings.isEmpty {
                                let averageScore = Double(communityRatings.reduce(0) { $0 + $1.value }) / Double(communityRatings.count)
                                let totalRatings = communityRatings.count
                                
                                // Get spot details
                                let spotDetail = spotDetails[spotId] ?? (name: "Unknown Location", address: "Address not available")
                                
                                let topSpot = TopSpotItem(
                                    id: spotId,
                                    name: spotDetail.name,
                                    address: spotDetail.address,
                                    userRating: 5,
                                    communityScore: averageScore,
                                    communityRatingCount: totalRatings
                                )
                                allSpots.append(topSpot)
                            }
                        }
                        
                        processedCount += batchSpotIds.count
                        
                        // Check if we've processed all batches
                        if processedCount >= spotIds.count {
                            // Sort by community score (descending) and take top 10
                            let sortedSpots = allSpots
                                .sorted { $0.communityScore > $1.communityScore }
                                .prefix(10)
                            
                            self.isLoading = false
                            self.topSpots = Array(sortedSpots)
                        } else {
                            // Process next batch
                            let nextBatchStart = processedCount
                            let nextBatchEnd = min(nextBatchStart + batchSize, spotIds.count)
                            let nextBatch = Array(spotIds[nextBatchStart..<nextBatchEnd])
                            processBatch(nextBatch)
                        }
                    }
                }
        }
        
        // Start with first batch
        let firstBatch = Array(spotIds.prefix(batchSize))
        processBatch(firstBatch)
    }
}

// MARK: - Top Spot Item Model
struct TopSpotItem: Identifiable {
    let id: String
    let name: String
    let address: String
    let userRating: Int
    let communityScore: Double
    let communityRatingCount: Int
}

// MARK: - Top Spot Card View
struct TopSpotCard: View {
    let spot: TopSpotItem
    let rank: Int
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            HStack {
                // Rank badge
                ZStack {
                    Circle()
                        .fill(DesignSystem.Colors.primary)
                        .frame(width: 32, height: 32)
                    
                    Text("\(rank)")
                        .font(DesignSystem.Typography.bodyMedium)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text(spot.name)
                        .font(DesignSystem.Typography.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .lineLimit(2)
                    
                    Text(spot.address)
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: DesignSystem.Spacing.xs) {
                    // User's rating
                    HStack(spacing: 4) {
                        Text("Your Rating:")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        
                        HStack(spacing: 2) {
                            ForEach(0..<5) { index in
                                Image(systemName: index < spot.userRating ? "star.fill" : "star")
                                    .font(.caption)
                                    .foregroundColor(DesignSystem.Colors.ratingGreen)
                            }
                        }
                    }
                    
                    // Community score
                    HStack(spacing: 4) {
                        Text("Community:")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        
                        Text(String(format: "%.1f★", spot.communityScore))
                            .font(DesignSystem.Typography.bodyMedium)
                            .fontWeight(.medium)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        
                        Text("(\(spot.communityRatingCount))")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                }
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                .stroke(DesignSystem.Colors.border, lineWidth: 1)
        )
    }
}

#Preview {
    UserTopSpotsView()
        .environmentObject(SessionStore())
}
