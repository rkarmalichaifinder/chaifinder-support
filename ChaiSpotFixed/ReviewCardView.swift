import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct ReviewCardView: View {
    let review: ReviewFeedItem
    @State private var spotName: String
    @State private var spotAddress: String
    @State private var isLoadingSpotInfo = false
    @State private var hasLoadedSpotInfo = false
    @State private var isLiked = false
    @State private var likeCount = 0
    @State private var showingComments = false
    @State private var showingShareSheet = false
    
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
                Button(action: {
                    showingComments = true
                }) {
                    Text(spotName)
                        .font(DesignSystem.Typography.headline)
                        .fontWeight(.bold)
                        .foregroundColor(DesignSystem.Colors.primary)
                        .multilineTextAlignment(.leading)
                }
                .buttonStyle(PlainButtonStyle())
                
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
                    toggleLike()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .font(.caption)
                            .foregroundColor(isLiked ? .red : DesignSystem.Colors.textSecondary)
                        Text("\(likeCount)")
                            .font(DesignSystem.Typography.caption)
                    }
                    .foregroundColor(isLiked ? .red : DesignSystem.Colors.textSecondary)
                }
                
                Button(action: {
                    showingComments = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "message")
                            .font(.caption)
                        Text("Comments")
                            .font(DesignSystem.Typography.caption)
                    }
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                
                Spacer()
                
                Button(action: {
                    showingShareSheet = true
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
            // Load like status and count
            loadLikeStatus()
        }
        .sheet(isPresented: $showingComments) {
            CommentListView(spotId: review.spotId)
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(activityItems: [createShareText()])
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
    
    // MARK: - Helper Functions
    
    private func toggleLike() {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            print("❌ User not logged in")
            return
        }
        
        let db = Firestore.firestore()
        let likeRef = db.collection("ratings").document(review.id).collection("likes").document(currentUserId)
        
        if isLiked {
            // Unlike
            likeRef.delete { error in
                if let error = error {
                    print("❌ Error unliking: \(error.localizedDescription)")
                } else {
                    DispatchQueue.main.async {
                        self.isLiked = false
                        self.likeCount = max(0, self.likeCount - 1)
                    }
                }
            }
        } else {
            // Like
            likeRef.setData([
                "userId": currentUserId,
                "timestamp": FieldValue.serverTimestamp()
            ]) { error in
                if let error = error {
                    print("❌ Error liking: \(error.localizedDescription)")
                } else {
                    DispatchQueue.main.async {
                        self.isLiked = true
                        self.likeCount += 1
                    }
                }
            }
        }
    }
    
    private func loadLikeStatus() {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        let db = Firestore.firestore()
        let likeRef = db.collection("ratings").document(review.id).collection("likes").document(currentUserId)
        
        // Check if user has liked this review
        likeRef.getDocument { snapshot, error in
            DispatchQueue.main.async {
                self.isLiked = snapshot?.exists ?? false
            }
        }
        
        // Get total like count
        db.collection("ratings").document(review.id).collection("likes").getDocuments { snapshot, error in
            DispatchQueue.main.async {
                self.likeCount = snapshot?.documents.count ?? 0
            }
        }
    }
    
    private func createShareText() -> String {
        let shareText = """
        Check out this chai spot review on Chai Finder!
        
        \(spotName)
        \(spotAddress)
        
        Rating: \(review.rating)★
        \(review.comment ?? "")
        
        Reviewed by: \(review.username)
        
        Download Chai Finder to discover more great chai spots!
        """
        return shareText
    }
}

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
} 