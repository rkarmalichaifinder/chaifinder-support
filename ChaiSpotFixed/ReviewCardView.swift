import SwiftUI
import FirebaseFirestore

struct ReviewCardView: View {
    let review: ReviewFeedItem
    @State private var spotName: String
    @State private var spotAddress: String
    @State private var isLoadingSpotInfo = false
    @State private var hasLoadedSpotInfo = false
    
    init(review: ReviewFeedItem) {
        self.review = review
        // Initialize with the review's spot info
        self._spotName = State(initialValue: review.spotName)
        self._spotAddress = State(initialValue: review.spotAddress)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Header
            HStack {
                // Profile Icon
                Circle()
                    .fill(DesignSystem.Colors.primary)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(String(review.username.prefix(1)).uppercased())
                            .font(DesignSystem.Typography.bodyMedium)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    )
                
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text(review.username)
                        .font(DesignSystem.Typography.bodyMedium)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    
                    Text(review.timestamp, style: .relative)
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                
                Spacer()
                
                // Rating
                Text("\(review.rating)★")
                    .font(DesignSystem.Typography.bodyMedium)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, DesignSystem.Spacing.sm)
                    .padding(.vertical, DesignSystem.Spacing.xs)
                    .background(DesignSystem.Colors.ratingGreen)
                    .cornerRadius(DesignSystem.CornerRadius.small)
            }
            
            // Spot Information
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(spotName)
                    .font(DesignSystem.Typography.headline)
                    .fontWeight(.bold)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                
                Text(spotAddress)
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
            
            // Chai Type
            if let chaiType = review.chaiType, !chaiType.isEmpty {
                HStack {
                    Image(systemName: "cup.and.saucer.fill")
                        .foregroundColor(DesignSystem.Colors.secondary)
                        .font(.caption)
                    
                    Text(chaiType)
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }
            
            // Comment
            if let comment = review.comment, !comment.isEmpty {
                Text(comment)
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .padding(DesignSystem.Spacing.md)
                    .background(DesignSystem.Colors.secondary.opacity(0.05))
                    .cornerRadius(DesignSystem.CornerRadius.small)
            }
            
            // Action Buttons
            HStack(spacing: DesignSystem.Spacing.md) {
                Button(action: {
                    // Like action
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "heart")
                            .font(.caption)
                        Text("Like")
                            .font(DesignSystem.Typography.caption)
                    }
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                
                Button(action: {
                    // Comment action
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "message")
                            .font(.caption)
                        Text("Comment")
                            .font(DesignSystem.Typography.caption)
                    }
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                
                Spacer()
                
                Button(action: {
                    // Share action
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.caption)
                        Text("Share")
                            .font(DesignSystem.Typography.caption)
                    }
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.medium)
        .shadow(
            color: DesignSystem.Shadows.small.color,
            radius: DesignSystem.Shadows.small.radius,
            x: DesignSystem.Shadows.small.x,
            y: DesignSystem.Shadows.small.y
        )
        .onAppear {
            // Load spot information if it's still a placeholder and hasn't been loaded yet
            if !hasLoadedSpotInfo && (spotName.hasPrefix("Chai Spot #") || spotName == "Loading...") {
                loadSpotInformation()
            }
        }
    }
    
    private func loadSpotInformation() {
        guard !isLoadingSpotInfo else { return }
        isLoadingSpotInfo = true
        
        let db = Firestore.firestore()
        
        // Add retry logic for permission issues
        func attemptLoad(retryCount: Int = 0) {
            db.collection("chaiFinder").document(review.spotId).getDocument { snapshot, error in
                DispatchQueue.main.async {
                    self.isLoadingSpotInfo = false
                    
                    if let error = error {
                        print("❌ Error loading spot information (attempt \(retryCount + 1)): \(error.localizedDescription)")
                        
                        // Retry once for permission issues
                        if retryCount == 0 && error.localizedDescription.contains("permissions") {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                attemptLoad(retryCount: 1)
                            }
                            return
                        }
                        
                        // Set fallback values if loading fails
                        self.spotName = "Chai Spot #\(self.review.spotId.prefix(6))"
                        self.spotAddress = "Tap to view details"
                        self.hasLoadedSpotInfo = true // Mark as loaded to prevent retries
                        return
                    }
                    
                    if let spotData = snapshot?.data(),
                       let name = spotData["name"] as? String,
                       let address = spotData["address"] as? String {
                        self.spotName = name
                        self.spotAddress = address
                        self.hasLoadedSpotInfo = true // Mark as loaded
                    } else {
                        // Set fallback values if loading fails
                        self.spotName = "Chai Spot #\(self.review.spotId.prefix(6))"
                        self.spotAddress = "Tap to view details"
                        self.hasLoadedSpotInfo = true // Mark as loaded to prevent retries
                    }
                }
            }
        }
        
        attemptLoad()
    }
} 