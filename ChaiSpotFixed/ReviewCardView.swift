import SwiftUI
import FirebaseFirestore
import FirebaseAuth

// Notification names for saved spots updates

// MARK: - Rating Bar View
struct RatingBarView: View {
    let rating: Int
    let maxRating: Int
    let iconName: String
    let activeColor: Color
    let inactiveColor: Color
    let label: String
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Text(label)
                .font(DesignSystem.Typography.bodyMedium)
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .fontWeight(.medium)
                .frame(width: 80, alignment: .leading)
            
            HStack(spacing: 2) {
                ForEach(1...maxRating, id: \.self) { i in
                    Image(systemName: i <= rating ? "\(iconName).fill" : iconName)
                        .foregroundColor(i <= rating ? activeColor : inactiveColor)
                        .font(.system(size: UIDevice.current.userInterfaceIdiom == .pad ? 16 : 14))
                }
            }
            
            Text("\(rating)/\(maxRating)")
                .font(DesignSystem.Typography.bodyMedium)
                .foregroundColor(activeColor)
                .fontWeight(.semibold)
                .frame(width: 35, alignment: .trailing)
        }
        .padding(.vertical, DesignSystem.Spacing.xs)
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.small)
        .shadow(
            color: Color.black.opacity(0.02), // Very subtle shadow
            radius: 1,
            x: 0,
            y: 0.5
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                .stroke(DesignSystem.Colors.border.opacity(0.08), lineWidth: 0.1) // Reduced from 0.3 opacity and 0.5 lineWidth
        )
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
    
    @EnvironmentObject var sessionStore: SessionStore
    
    init(review: ReviewFeedItem) {
        self.review = review
        // Initialize with the review's spot info
        self._spotName = State(initialValue: review.spotName)
        self._spotAddress = State(initialValue: review.spotAddress)
    }
    
    var body: some View {
        Button(action: {
            showingComments = true
        }) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                // 🎮 NEW: Social Reactions - Compact horizontal layout with no text wrapping
                HStack(spacing: 6) {
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
                    
                    // Show reaction counts if any exist
                    if !userReactions.isEmpty {
                        HStack(spacing: 6) {
                            ForEach(Array(userReactions.keys.sorted()), id: \.self) { reactionType in
                                if let count = userReactions[reactionType], count > 0 {
                                    HStack(spacing: 3) { // Increased from 2 to 3 for better spacing
                                        Text(Rating.ReactionType(rawValue: reactionType)?.emoji ?? "👍")
                                            .font(.caption)
                                        
                                        Text("\(count)")
                                            .font(DesignSystem.Typography.caption)
                                            .fontWeight(.medium)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.horizontal, 6) // Increased from 4 to 6
                                    .padding(.vertical, 3) // Increased from 2 to 3
                                    .background(Color.gray.opacity(0.08)) // Reduced from 0.1 to 0.08 for subtler appearance
                                    .cornerRadius(8) // Increased from 6 to 8 for consistency
                                }
                            }
                        }
                    }
                }
                .padding(.bottom, 4) // Reduced from 6 to 4 for more compact layout
                
                // Header
                HStack(alignment: .top, spacing: 8) {
                    // Profile Icon
                    Circle()
                        .fill(DesignSystem.Colors.primary)
                        .frame(width: 36, height: 36)
                        .overlay(
                            Text(String(review.username.prefix(1)).uppercased())
                                .font(DesignSystem.Typography.bodySmall)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        )
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(review.username)
                            .font(DesignSystem.Typography.bodyMedium)
                            .fontWeight(.semibold)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        
                        Text(review.timestamp.timeAgoDisplay())
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    
                    Spacer()
                    
                    // Rating stars
                    HStack(spacing: 1) {
                        ForEach(1...5, id: \.self) { i in
                            Image(systemName: i <= review.rating ? "star.fill" : "star")
                                .foregroundColor(i <= review.rating ? .yellow : .gray.opacity(0.3))
                                .font(.system(size: 10))
                        }
                    }
                }
                
                // 🎮 NEW: Photo Display
                if let photoURL = review.photoURL, !photoURL.isEmpty {
                    VStack(spacing: 6) {
                        CachedAsyncImage(url: photoURL, cornerRadius: 12)
                            .frame(height: 200)
                        
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
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                
                // Spot Information
                VStack(alignment: .leading, spacing: 4) {
                    Text(spotName == "Loading..." ? review.spotName : spotName)
                        .font(DesignSystem.Typography.bodyMedium)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignSystem.Colors.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    Text(spotAddress == "Loading..." ? review.spotAddress : spotAddress)
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                }
                .padding(.top, 4)
                
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
                
                // Improved Rating Information Layout - More Compact
                VStack(alignment: .leading, spacing: 6) {
                    Text("Rating Details")
                        .font(DesignSystem.Typography.bodySmall)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    
                    // Compact rating layout with better spacing
                    VStack(spacing: 6) {
                        // Creaminess Rating
                        if let creaminessRating = review.creaminessRating {
                            HStack(spacing: 8) {
                                Text("Creaminess")
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                                    .frame(width: 70, alignment: .leading)
                                
                                HStack(spacing: 2) {
                                    ForEach(1...5, id: \.self) { i in
                                        Image(systemName: i <= creaminessRating ? "drop.fill" : "drop")
                                            .foregroundColor(i <= creaminessRating ? .brown : .gray.opacity(0.3))
                                            .font(.system(size: 10))
                                    }
                                }
                                
                                Text("\(creaminessRating)/5")
                                    .font(DesignSystem.Typography.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(DesignSystem.Colors.textPrimary)
                                    .frame(width: 25, alignment: .trailing)
                            }
                        }
                        
                        // Chai Strength Rating
                        if let chaiStrengthRating = review.chaiStrengthRating {
                            HStack(spacing: 8) {
                                Text("Strength")
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                                    .frame(width: 70, alignment: .leading)
                                
                                HStack(spacing: 2) {
                                    ForEach(1...5, id: \.self) { i in
                                        Image(systemName: i <= chaiStrengthRating ? "leaf.fill" : "leaf")
                                            .foregroundColor(i <= chaiStrengthRating ? .green : .gray.opacity(0.3))
                                            .font(.system(size: 10))
                                    }
                                }
                                
                                Text("\(chaiStrengthRating)/5")
                                    .font(DesignSystem.Typography.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(DesignSystem.Colors.textPrimary)
                                    .frame(width: 25, alignment: .trailing)
                            }
                        }
                    }
                }
                .padding(.top, 6)
                
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
                
                // Comment
                if let comment = review.comment, !comment.isEmpty {
                    Text(comment)
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .padding(.top, DesignSystem.Spacing.xs)
                }
                
                // Action Buttons
                HStack(spacing: DesignSystem.Spacing.md) {
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
            .padding(DesignSystem.Spacing.md)
            .background(DesignSystem.Colors.cardBackground)
            .cornerRadius(DesignSystem.CornerRadius.medium)
            .shadow(
                color: Color.black.opacity(0.03), // Very subtle shadow
                radius: 2,
                x: 0,
                y: 1
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                    .stroke(DesignSystem.Colors.border.opacity(0.08), lineWidth: 0.1) // Reduced from 0.15 opacity and 0.2 lineWidth
            )
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingComments) {
            CommentListView(
                spotId: review.spotId,
                spotName: spotName,
                spotAddress: spotAddress
            )
            .environmentObject(sessionStore)
        }
        .sheet(isPresented: $showingShareSheet) {
            let place = (spotName == "Loading..." ? review.spotName : spotName)
            let location = (spotAddress == "Loading..." ? review.spotAddress : spotAddress)
            let commentText = (review.comment?.isEmpty == false) ? "\"\(review.comment!)\"" : "No comment"
            
            // 🆕 Enhanced sharing with multiple formats for different platforms
            let shareItems = createMultiFormatShareItems(
                place: place,
                location: location,
                rating: review.rating,
                username: review.username,
                comment: commentText
            )
            
            ShareSheet(
                activityItems: shareItems,
                reviewId: review.id,
                spotName: place,
                spotAddress: location
            )
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
        let ratingRef = db.collection("ratings").document(review.id)
        
        if selectedReaction == reactionType {
            // Remove reaction
            let currentCount = userReactions[reactionType.rawValue] ?? 0
            let newCount = max(0, currentCount - 1)
            
            ratingRef.updateData([
                "reactions.\(reactionType.rawValue)": newCount
            ]) { error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("❌ Error removing reaction: \(error.localizedDescription)")
                    } else {
                        selectedReaction = nil
                        updateReactionCount(reactionType: reactionType, increment: -1)
                        
                        // 🆕 Trigger feed refresh for reaction update
                        NotificationCenter.default.post(name: .reactionUpdated, object: nil)
                    }
                }
            }
        } else {
            // Add/change reaction
            let currentCount = userReactions[reactionType.rawValue] ?? 0
            let newCount = currentCount + 1
            
            ratingRef.updateData([
                "reactions.\(reactionType.rawValue)": newCount
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
                        
                        // 🆕 Trigger feed refresh for reaction update
                        NotificationCenter.default.post(name: .reactionUpdated, object: nil)
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
        // Use reactions from the ReviewFeedItem
        userReactions = review.reactions
        
        // Check if user has already reacted to this review
        // This would need to be implemented separately if you want to track individual user reactions
        // For now, we'll just display the total reaction counts
    }
    
    // 🆕 Create enhanced share message with deep link
    private func createEnhancedShareMessage(place: String, location: String, rating: Int, username: String, comment: String) -> String {
        // Create a deep link to this specific review with additional context
        let deepLink = createDeepLink()
        
        // App Store link for Chai Finder
        let appStoreLink = "https://apps.apple.com/us/app/chai-finder/id6747459183"
        
        // Create the share message
        let message = """
        🫖 Check out this Chai Finder review!
        
        📍 \(place) (\(location))
        ⭐ \(rating)★ by \(username)
        💬 \(comment)
        
        🔗 View in Chai Finder: \(deepLink)
        
        📱 Download Chai Finder: \(appStoreLink)
        
        #ChaiFinder #ChaiLover #TeaTime
        """
        
        return message
    }
    
    // 🆕 Create a sophisticated deep link with context
    private func createDeepLink() -> String {
        // Create a deep link that includes review context
        var components = ["chaifinder://review"]
        
        // Add review ID
        components.append(review.id)
        
        // Add spot context if available
        if !review.spotId.isEmpty {
            components.append("spot/\(review.spotId)")
        }
        
        // Add rating context
        components.append("rating/\(review.rating)")
        
        // Add user context
        components.append("user/\(review.userId)")
        
        // Join components with slashes
        let deepLink = components.joined(separator: "/")
        
        // Add query parameters for additional context
        var queryParams: [String] = []
        
        if let chaiType = review.chaiType, !chaiType.isEmpty {
            queryParams.append("chaiType=\(chaiType.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? chaiType)")
        }
        
        if let creaminessRating = review.creaminessRating {
            queryParams.append("creaminess=\(creaminessRating)")
        }
        
        if let chaiStrengthRating = review.chaiStrengthRating {
            queryParams.append("strength=\(chaiStrengthRating)")
        }
        
        if let flavorNotes = review.flavorNotes, !flavorNotes.isEmpty {
            let notesString = flavorNotes.joined(separator: ",")
            queryParams.append("flavors=\(notesString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? notesString)")
        }
        
        // Combine deep link with query parameters
        if !queryParams.isEmpty {
            return "\(deepLink)?\(queryParams.joined(separator: "&"))"
        }
        
        return deepLink
    }
    
    // 🆕 Create HTML email template for better email sharing
    private func createHTMLEmailTemplate(place: String, location: String, rating: Int, username: String, comment: String) -> String {
        let deepLink = createDeepLink()
        let appStoreLink = "https://apps.apple.com/us/app/chai-finder/id6747459183"
        
        let htmlTemplate = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Chai Finder Review - \(place)</title>
            <style>
                body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; line-height: 1.6; color: #333; }
                .container { max-width: 600px; margin: 0 auto; padding: 20px; }
                .header { background: linear-gradient(135deg, #c1440e, #e67e22); color: white; padding: 30px; text-align: center; border-radius: 10px 10px 0 0; }
                .content { background: #f8f9fa; padding: 30px; border-radius: 0 0 10px 10px; }
                .review-card { background: white; padding: 20px; border-radius: 8px; margin: 20px 0; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
                .rating { color: #f39c12; font-size: 18px; font-weight: bold; }
                .location { color: #7f8c8d; font-size: 14px; }
                .comment { font-style: italic; color: #555; margin: 15px 0; }
                .cta-button { display: inline-block; background: #c1440e; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; margin: 10px 5px; }
                .footer { text-align: center; margin-top: 30px; color: #7f8c8d; font-size: 12px; }
            </style>
        </head>
        <body>
            <div class="container">
                <div class="header">
                    <h1>🫖 Chai Finder Review</h1>
                    <p>Discover amazing chai spots through trusted recommendations</p>
                </div>
                
                <div class="content">
                    <div class="review-card">
                        <h2>📍 \(place)</h2>
                        <p class="location">\(location)</p>
                        <p class="rating">⭐ \(rating)★ by \(username)</p>
                        <div class="comment">"\(comment)"</div>
                    </div>
                    
                    <p>This review was shared with you from the Chai Finder app - where chai lovers discover and share their favorite spots!</p>
                    
                    <div style="text-align: center; margin: 30px 0;">
                        <a href="\(deepLink)" class="cta-button">View in Chai Finder</a>
                        <a href="\(appStoreLink)" class="cta-button">Download App</a>
                    </div>
                    
                    <p><strong>Why Chai Finder?</strong></p>
                    <ul>
                        <li>✨ Discover authentic chai through trusted friends</li>
                        <li>📍 Find the best spots in your area</li>
                        <li>💬 Read detailed reviews and ratings</li>
                        <li>🫖 Connect with fellow chai enthusiasts</li>
                    </ul>
                </div>
                
                <div class="footer">
                    <p>Shared from Chai Finder • <a href="\(appStoreLink)">Download on the App Store</a></p>
                    <p>© 2024 Chai Finder. All rights reserved.</p>
                </div>
            </div>
        </body>
        </html>
        """
        
        return htmlTemplate
    }
    
    // 🆕 Create plain text email template for email clients that don't support HTML
    private func createPlainTextEmailTemplate(place: String, location: String, rating: Int, username: String, comment: String) -> String {
        let deepLink = createDeepLink()
        let appStoreLink = "https://apps.apple.com/us/app/chai-finder/id6747459183"
        
        let plainTextTemplate = """
        🫖 Chai Finder Review
        
        📍 \(place)
        📍 \(location)
        ⭐ \(rating)★ by \(username)
        💬 \(comment)
        
        This review was shared with you from the Chai Finder app - where chai lovers discover and share their favorite spots!
        
        🔗 View in Chai Finder: \(deepLink)
        📱 Download Chai Finder: \(appStoreLink)
        
        Why Chai Finder?
        ✨ Discover authentic chai through trusted friends
        📍 Find the best spots in your area
        💬 Read detailed reviews and ratings
        🫖 Connect with fellow chai enthusiasts
        
        Shared from Chai Finder
        Download on the App Store: \(appStoreLink)
        """
        
        return plainTextTemplate
    }
    
    // 🆕 Create multiple share formats for different platforms
    private func createMultiFormatShareItems(place: String, location: String, rating: Int, username: String, comment: String) -> [Any] {
        // Create different formats for different sharing methods
        let plainText = createEnhancedShareMessage(place: place, location: location, rating: rating, username: username, comment: comment)
        let htmlEmail = createHTMLEmailTemplate(place: place, location: location, rating: rating, username: username, comment: comment)
        let plainEmail = createPlainTextEmailTemplate(place: place, location: location, rating: rating, username: username, comment: comment)
        
        // Create a custom activity item that provides different content based on the activity type
        let customActivityItem = CustomShareActivityItem(
            plainText: plainText,
            htmlEmail: htmlEmail,
            plainEmail: plainEmail,
            reviewId: review.id,
            spotName: place
        )
        
        return [customActivityItem]
    }
    
    private func loadSpotInfo() {
        if hasLoadedSpotInfo { return }
        
        isLoadingSpotInfo = true
        let db = Firestore.firestore()
        
        // Try both collections - chaiFinder and chaiSpots
        let collections = ["chaiFinder", "chaiSpots"]
        var currentCollectionIndex = 0
        
        func tryNextCollection() {
            guard currentCollectionIndex < collections.count else {
                // All collections failed, use fallback
                DispatchQueue.main.async {
                    isLoadingSpotInfo = false
                    hasLoadedSpotInfo = true
                    spotName = review.spotName
                    spotAddress = review.spotAddress
                }
                return
            }
            
            let collectionName = collections[currentCollectionIndex]
            currentCollectionIndex += 1
            
            db.collection(collectionName).document(review.spotId).getDocument { document, error in
                DispatchQueue.main.async {
                    if let error = error {
                        // Try the next collection if this one failed
                        print("Failed to load from collection \(collectionName): \(error.localizedDescription)")
                        tryNextCollection()
                        return
                    }
                    
                    if let document = document, document.exists {
                        let data = document.data()
                        spotName = data?["name"] as? String ?? review.spotName
                        spotAddress = data?["address"] as? String ?? review.spotAddress
                        isLoadingSpotInfo = false
                        hasLoadedSpotInfo = true
                    } else {
                        // Document doesn't exist, try the next collection
                        tryNextCollection()
                    }
                }
            }
        }
        
        tryNextCollection()
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
                        // Post notification to update profile count
                        NotificationCenter.default.post(name: .savedSpotsChanged, object: nil)
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
                        // Post notification to update profile count
                        NotificationCenter.default.post(name: .savedSpotsChanged, object: nil)
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

// MARK: - Reaction Button
struct ReactionButton: View {
    let reactionType: Rating.ReactionType
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) { // Increased from 3 to 4 for better spacing
                Text(reactionType.emoji)
                    .font(.system(size: 14)) // Increased from 12 to 14 for better visibility
                
                Text(reactionType.displayName)
                    .font(DesignSystem.Typography.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .foregroundColor(isSelected ? .white : DesignSystem.Colors.textSecondary)
            .padding(.horizontal, 8) // Increased from 6 to 8 for better touch target
            .padding(.vertical, 6) // Increased from 4 to 6 for better touch target
            .frame(minWidth: 64, maxWidth: 76) // Increased from 60/70 to 64/76 for better touch target
            .background(
                RoundedRectangle(cornerRadius: 8) // Increased from 6 to 8 for better visual appeal
                    .fill(isSelected ? DesignSystem.Colors.primary : Color.gray.opacity(0.06)) // Reduced from 0.08 to 0.06 for subtler appearance
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8) // Increased from 6 to 8
                    .stroke(isSelected ? DesignSystem.Colors.primary : Color.gray.opacity(0.15), lineWidth: 0.5) // Reduced from 0.2 to 0.15 for subtler appearance
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isSelected ? 1.02 : 1.0) // Reduced from 1.05 to 1.02 for subtler animation
        .animation(.easeInOut(duration: 0.15), value: isSelected) // Increased from 0.1 to 0.15 for smoother animation
        .accessibilityLabel("\(reactionType.displayName) reaction")
        .accessibilityHint("Double tap to \(isSelected ? "remove" : "add") \(reactionType.displayName) reaction")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Enhanced Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    let reviewId: String
    let spotName: String
    let spotAddress: String
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        
        // 🆕 Customize the share sheet for better email experience
        controller.excludedActivityTypes = [
            .assignToContact,
            .addToReadingList,
            .openInIBooks,
            .markupAsPDF
        ]
        
        // 🆕 Set completion handler to track sharing
        controller.completionWithItemsHandler = { (activityType, completed, returnedItems, error) in
            if completed {
                print("✅ Review shared via: \(activityType?.rawValue ?? "unknown")")
                
                // Track email sharing specifically
                if activityType == .mail {
                    print("📧 Review shared via email: \(self.reviewId)")
                }
            }
        }
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Custom Share Activity Item
class CustomShareActivityItem: NSObject, UIActivityItemSource {
    let plainText: String
    let htmlEmail: String
    let plainEmail: String
    let reviewId: String
    let spotName: String
    
    init(plainText: String, htmlEmail: String, plainEmail: String, reviewId: String, spotName: String) {
        self.plainText = plainText
        self.htmlEmail = htmlEmail
        self.plainEmail = plainEmail
        self.reviewId = reviewId
        self.spotName = spotName
        super.init()
    }
    
    // 🆕 Provide different content based on activity type
    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        return plainText
    }
    
    func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        guard let activityType = activityType else { return plainText }
        
        switch activityType {
        case .mail:
            // For email, provide HTML content if possible, otherwise plain text
            return htmlEmail
        case .message, .postToFacebook, .postToTwitter, .postToWeibo:
            // For social media, use plain text with emojis
            return plainText
        default:
            // For other activities, use plain text
            return plainText
        }
    }
    
    func activityViewController(_ activityViewController: UIActivityViewController, subjectForActivityType activityType: UIActivity.ActivityType?) -> String {
        return "Chai Finder Review - \(spotName)"
    }
    
    func activityViewController(_ activityViewController: UIActivityViewController, dataTypeIdentifierForActivityType activityType: UIActivity.ActivityType?) -> String {
        if activityType == .mail {
            return "public.html"
        }
        return "public.plain-text"
    }
} 

// MARK: - Date Extension
extension Date {
    func timeAgoDisplay() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
} 