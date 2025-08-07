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
    @State private var isSpotSaved = false
    @State private var showingActionSheet = false
    @State private var showingReportSheet = false
    @State private var showingBlockAlert = false
    @StateObject private var moderationService = ContentModerationService()
    
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
                
                // More options button
                Button(action: {
                    showingActionSheet = true
                }) {
                    Image(systemName: "ellipsis")
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
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
                    Text("Chai Type:")
                        .font(DesignSystem.Typography.bodySmall)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    
                    Text(chaiType)
                        .font(DesignSystem.Typography.bodySmall)
                        .fontWeight(.medium)
                        .foregroundColor(DesignSystem.Colors.primary)
                        .padding(.horizontal, DesignSystem.Spacing.sm)
                        .padding(.vertical, 2)
                        .background(DesignSystem.Colors.primary.opacity(0.1))
                        .cornerRadius(DesignSystem.CornerRadius.small)
                }
            }
            
            // Review Comment
            if let comment = review.comment, !comment.isEmpty {
                Text(comment)
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .padding(.top, DesignSystem.Spacing.xs)
            }
            
            // Action Buttons
            HStack(spacing: DesignSystem.Spacing.lg) {
                Button(action: {
                    // Like functionality
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .foregroundColor(isLiked ? .red : DesignSystem.Colors.textSecondary)
                        Text("\(likeCount)")
                            .font(DesignSystem.Typography.bodySmall)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                }
                
                Button(action: {
                    showingComments = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "bubble.left")
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        Text("Comments")
                            .font(DesignSystem.Typography.bodySmall)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                }
                
                Spacer()
                
                Button(action: {
                    showingShareSheet = true
                }) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }
            .padding(.top, DesignSystem.Spacing.sm)
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.medium)
        .sheet(isPresented: $showingComments) {
            CommentListView(spotId: review.spotId, spotName: spotName)
        }
        .sheet(isPresented: $showingReportSheet) {
            ReportContentView(
                contentId: review.id,
                contentType: .rating,
                contentPreview: "\(review.username): \(review.comment ?? "No comment")"
            )
        }
        .actionSheet(isPresented: $showingActionSheet) {
            ActionSheet(
                title: Text("Review Options"),
                buttons: [
                    .default(Text("Report Review")) {
                        showingReportSheet = true
                    },
                    .default(Text("Block \(review.username)")) {
                        showingBlockAlert = true
                    },
                    .cancel()
                ]
            )
        }
        .alert("Block User", isPresented: $showingBlockAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Block", role: .destructive) {
                blockUser()
            }
        } message: {
            Text("Are you sure you want to block \(review.username)? You won't see their content anymore.")
        }
        .onAppear {
            loadSpotInfo()
        }
    }
    
    private func loadSpotInfo() {
        if hasLoadedSpotInfo { return }
        
        isLoadingSpotInfo = true
        let db = Firestore.firestore()
        
        db.collection("spots").document(review.spotId).getDocument { document, error in
            DispatchQueue.main.async {
                isLoadingSpotInfo = false
                hasLoadedSpotInfo = true
                
                if let document = document, document.exists {
                    let data = document.data()
                    spotName = data?["name"] as? String ?? review.spotName
                    spotAddress = data?["address"] as? String ?? review.spotAddress
                }
            }
        }
    }
    
    private func blockUser() {
        moderationService.blockUser(userIdToBlock: review.userId)
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