import SwiftUI
import FirebaseFirestore
import FirebaseAuth

// MARK: - Rating Bar View
struct RatingBarView: View {
    let rating: Int
    let maxRating: Int
    let iconName: String
    let activeColor: Color
    let inactiveColor: Color
    let label: String
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            Text(label)
                .font(DesignSystem.Typography.bodySmall)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .frame(width: 60, alignment: .leading)
            
            HStack(spacing: 2) {
                ForEach(1...maxRating, id: \.self) { i in
                    Image(systemName: i <= rating ? "\(iconName).fill" : iconName)
                        .foregroundColor(i <= rating ? activeColor : inactiveColor)
                        .font(.system(size: 12))
                }
            }
            
            Text("\(rating)/\(maxRating)")
                .font(DesignSystem.Typography.bodySmall)
                .foregroundColor(activeColor)
                .fontWeight(.medium)
        }
    }
}

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
    
    // 🎮 NEW: Social reactions states
    @State private var userReactions: [String: Int] = [:]
    @State private var showingReactionPicker = false
    @State private var selectedReaction: Rating.ReactionType?
    
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
            
            // 🎮 NEW: Photo Display
            if let photoURL = review.photoURL, !photoURL.isEmpty {
                VStack(spacing: 8) {
                    AsyncImage(url: URL(string: photoURL)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 200)
                            .clipped()
                            .cornerRadius(12)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 200)
                            .overlay(
                                ProgressView()
                                    .scaleEffect(1.2)
                            )
                    }
                    
                    // Photo bonus indicator
                    HStack(spacing: 6) {
                        Image(systemName: "camera.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                        
                        Text("Photo included (+15 points)")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(.orange)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            
            // Spot Information
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Button(action: {
                    showingComments = true
                }) {
                    HStack {
                        Text(review.spotName == "Loading..." ? "Loading spot details..." : review.spotName)
                            .font(DesignSystem.Typography.headline)
                            .fontWeight(.bold)
                            .foregroundColor(review.spotName == "Loading..." ? DesignSystem.Colors.textSecondary : DesignSystem.Colors.primary)
                            .multilineTextAlignment(.leading)
                        
                        if review.spotName == "Loading..." {
                            ProgressView()
                                .scaleEffect(0.8)
                                .padding(.leading, 4)
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                Text(review.spotAddress == "Loading..." ? "Loading location..." : review.spotAddress)
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(review.spotAddress == "Loading..." ? DesignSystem.Colors.textSecondary.opacity(0.7) : DesignSystem.Colors.textSecondary)
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
            
            // New Rating Information - Always show all fields with "NR" if missing
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                Text("Rating Details")
                    .font(DesignSystem.Typography.bodySmall)
                    .fontWeight(.semibold)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                
                VStack(spacing: DesignSystem.Spacing.xs) {
                    // Creaminess Rating
                    if let creaminessRating = review.creaminessRating {
                        RatingBarView(
                            rating: creaminessRating,
                            maxRating: 5,
                            iconName: "drop",
                            activeColor: DesignSystem.Colors.creaminessRating,
                            inactiveColor: DesignSystem.Colors.border,
                            label: "Creaminess"
                        )
                    } else {
                        // Show "NR" for missing creaminess rating
                        HStack(spacing: DesignSystem.Spacing.xs) {
                            Text("Creaminess")
                                .font(DesignSystem.Typography.bodySmall)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                                .frame(width: 60, alignment: .leading)
                            
                            HStack(spacing: 2) {
                                ForEach(1...5, id: \.self) { i in
                                    Image(systemName: "drop")
                                        .foregroundColor(DesignSystem.Colors.border)
                                        .font(.system(size: 12))
                                }
                            }
                            
                            Text("NR")
                                .font(DesignSystem.Typography.bodySmall)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                                .fontWeight(.medium)
                        }
                    }
                    
                    // Chai Strength Rating
                    if let chaiStrengthRating = review.chaiStrengthRating {
                        RatingBarView(
                            rating: chaiStrengthRating,
                            maxRating: 5,
                            iconName: "leaf",
                            activeColor: DesignSystem.Colors.chaiStrengthRating,
                            inactiveColor: DesignSystem.Colors.border,
                            label: "Strength"
                        )
                    } else {
                        // Show "NR" for missing strength rating
                        HStack(spacing: DesignSystem.Spacing.xs) {
                            Text("Strength")
                                .font(DesignSystem.Typography.bodySmall)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                                .frame(width: 60, alignment: .leading)
                            
                            HStack(spacing: 2) {
                                ForEach(1...5, id: \.self) { i in
                                    Image(systemName: "leaf")
                                        .foregroundColor(DesignSystem.Colors.border)
                                        .font(.system(size: 12))
                                }
                            }
                            
                            Text("NR")
                                .font(DesignSystem.Typography.bodySmall)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                                .fontWeight(.medium)
                        }
                    }
                }
            }
            .padding(.top, DesignSystem.Spacing.xs)
            
            // Flavor Notes - Always show with "NR" if missing
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text("Flavor Notes:")
                    .font(DesignSystem.Typography.bodySmall)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                
                if let flavorNotes = review.flavorNotes, !flavorNotes.isEmpty {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: DesignSystem.Spacing.xs) {
                        ForEach(flavorNotes, id: \.self) { note in
                            Text(note)
                                .font(DesignSystem.Typography.bodySmall)
                                .foregroundColor(.white)
                                .padding(.horizontal, DesignSystem.Spacing.xs)
                                .padding(.vertical, 2)
                                .background(DesignSystem.Colors.flavorNotesRating)
                                .cornerRadius(DesignSystem.CornerRadius.small)
                        }
                    }
                } else {
                    // Show "NR" for missing flavor notes
                    Text("NR")
                        .font(DesignSystem.Typography.bodySmall)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .italic()
                        .padding(.horizontal, DesignSystem.Spacing.xs)
                        .padding(.vertical, 2)
                        .background(DesignSystem.Colors.border.opacity(0.3))
                        .cornerRadius(DesignSystem.CornerRadius.small)
                }
            }
            .padding(.top, DesignSystem.Spacing.xs)
            
            // Review Comment
            if let comment = review.comment, !comment.isEmpty {
                Text(comment)
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .padding(.top, DesignSystem.Spacing.xs)
            }
            
            // 🎮 NEW: Social Reactions
            VStack(spacing: 12) {
                // Reaction summary
                if !userReactions.isEmpty {
                    HStack(spacing: 12) {
                        ForEach(Array(userReactions.keys.sorted()), id: \.self) { reactionType in
                            if let count = userReactions[reactionType], count > 0 {
                                HStack(spacing: 4) {
                                    Text(Rating.ReactionType(rawValue: reactionType)?.emoji ?? "👍")
                                        .font(.caption)
                                    
                                    Text("\(count)")
                                        .font(DesignSystem.Typography.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(12)
                            }
                        }
                    }
                }
                
                // Reaction buttons
                HStack(spacing: 16) {
                    ForEach(Rating.ReactionType.allCases, id: \.self) { reactionType in
                        ReactionButton(
                            reactionType: reactionType,
                            isSelected: selectedReaction == reactionType,
                            onTap: {
                                handleReaction(reactionType)
                            }
                        )
                    }
                    
                    Spacer()
                }
            }
            .padding(.top, DesignSystem.Spacing.sm)
            
            // Action Buttons
            HStack(spacing: DesignSystem.Spacing.lg) {
                Button(action: {
                    toggleLike()
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
            CommentListView(spotId: review.spotId)
        }
        .sheet(isPresented: $showingShareSheet) {
            let place = (spotName == "Loading..." ? review.spotName : spotName)
            let location = (spotAddress == "Loading..." ? review.spotAddress : spotAddress)
            let commentText = (review.comment?.isEmpty == false) ? "\"\(review.comment!)\"" : "No comment"
            let message = "Check out this Chai Finder review of \(place) (\(location)) — \(review.rating)★ by \(review.username). \(commentText)"
            ShareSheet(activityItems: [message])
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
            checkLikeState()
            loadReactions()
        }
    }
    
    // 🎮 NEW: Handle reaction
    private func handleReaction(_ reactionType: Rating.ReactionType) {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        let db = Firestore.firestore()
        let reactionRef = db.collection("ratings").document(review.id).collection("reactions").document(currentUserId)
        
        if selectedReaction == reactionType {
            // Remove reaction
            reactionRef.delete { error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("❌ Error removing reaction: \(error.localizedDescription)")
                    } else {
                        selectedReaction = nil
                        updateReactionCount(reactionType: reactionType, increment: -1)
                    }
                }
            }
        } else {
            // Add/change reaction
            reactionRef.setData([
                "userId": currentUserId,
                "reactionType": reactionType.rawValue,
                "timestamp": FieldValue.serverTimestamp()
            ]) { error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("❌ Error adding reaction: \(error.localizedDescription)")
                    } else {
                        // Remove previous reaction count if exists
                        if let previous = selectedReaction {
                            updateReactionCount(reactionType: previous, increment: -1)
                        }
                        
                        selectedReaction = reactionType
                        updateReactionCount(reactionType: reactionType, increment: 1)
                    }
                }
            }
        }
    }
    
    // 🎮 NEW: Update reaction count
    private func updateReactionCount(reactionType: Rating.ReactionType, increment: Int) {
        let currentCount = userReactions[reactionType.rawValue] ?? 0
        let newCount = max(0, currentCount + increment)
        
        if newCount > 0 {
            userReactions[reactionType.rawValue] = newCount
        } else {
            userReactions.removeValue(forKey: reactionType.rawValue)
        }
    }
    
    // 🎮 NEW: Load reactions
    private func loadReactions() {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        let db = Firestore.firestore()
        
        // Load user's reaction
        let userReactionRef = db.collection("ratings").document(review.id).collection("reactions").document(currentUserId)
        userReactionRef.getDocument { document, error in
            DispatchQueue.main.async {
                if let document = document, document.exists,
                   let reactionType = document.get("reactionType") as? String {
                    self.selectedReaction = Rating.ReactionType(rawValue: reactionType)
                }
            }
        }
        
        // Load all reactions
        let reactionsRef = db.collection("ratings").document(review.id).collection("reactions")
        reactionsRef.getDocuments { snapshot, error in
            DispatchQueue.main.async {
                if let snapshot = snapshot {
                    var reactionCounts: [String: Int] = [:]
                    
                    for document in snapshot.documents {
                        if let reactionType = document.get("reactionType") as? String {
                            reactionCounts[reactionType, default: 0] += 1
                        }
                    }
                    
                    self.userReactions = reactionCounts
                }
            }
        }
    }
    
    private func loadSpotInfo() {
        if hasLoadedSpotInfo { return }
        
        isLoadingSpotInfo = true
        let db = Firestore.firestore()
        
        db.collection("chaiFinder").document(review.spotId).getDocument { document, error in
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
    
    private func toggleLike() {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            print("❌ User not authenticated, cannot like review")
            return
        }
        
        let db = Firestore.firestore()
        let likeRef = db.collection("reviews").document(review.id).collection("likes").document(currentUserId)
        
        if isLiked {
            // Unlike
            likeRef.delete { error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("❌ Error unliking review: \(error.localizedDescription)")
                    } else {
                        self.isLiked = false
                        self.likeCount = max(0, self.likeCount - 1)
                        print("✅ Review unliked successfully")
                        // Also remove from user's saved spots list
                        let userRef = db.collection("users").document(currentUserId)
                        userRef.setData(["savedSpots": FieldValue.arrayRemove([self.review.spotId])], merge: true)
                    }
                }
            }
        } else {
            // Like
            likeRef.setData([
                "userId": currentUserId,
                "timestamp": FieldValue.serverTimestamp()
            ]) { error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("❌ Error liking review: \(error.localizedDescription)")
                    } else {
                        self.isLiked = true
                        self.likeCount += 1
                        print("✅ Review liked successfully")
                        // Also add to user's saved spots list
                        let userRef = db.collection("users").document(currentUserId)
                        userRef.setData(["savedSpots": FieldValue.arrayUnion([self.review.spotId])], merge: true)
                    }
                }
            }
        }
    }
    
    private func checkLikeState() {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            return
        }
        
        let db = Firestore.firestore()
        let likeRef = db.collection("reviews").document(review.id).collection("likes").document(currentUserId)
        
        likeRef.getDocument { document, error in
            DispatchQueue.main.async {
                if let document = document, document.exists {
                    self.isLiked = true
                } else {
                    self.isLiked = false
                }
            }
        }
        
        // Get total like count
        db.collection("reviews").document(review.id).collection("likes").getDocuments { snapshot, error in
            DispatchQueue.main.async {
                if let snapshot = snapshot {
                    self.likeCount = snapshot.documents.count
                }
            }
        }
    }
}

// 🎮 NEW: Reaction Button
struct ReactionButton: View {
    let reactionType: Rating.ReactionType
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Text(reactionType.emoji)
                    .font(.title3)
                
                Text(reactionType.displayName)
                    .font(DesignSystem.Typography.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.orange.opacity(0.2) : Color.gray.opacity(0.1))
            .foregroundColor(isSelected ? .orange : .secondary)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.orange : Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isSelected)
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