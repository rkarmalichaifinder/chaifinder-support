import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore
import PhotosUI

// Notification names for rating updates
extension Notification.Name {
    static let ratingUpdated = Notification.Name("ratingUpdated")
    static let spotsUpdated = Notification.Name("spotsUpdated")
}

struct SubmitRatingView: View {
    let spotId: String
    let spotName: String
    let spotAddress: String
    let existingRating: Rating?
    let onComplete: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var sessionStore: SessionStore
    
    @State private var ratingValue: Int = 3
    @State private var comment: String = ""
    @State private var isSubmitting = false
    @State private var showContentWarning = false
    @State private var contentWarningMessage = ""
    @State private var inlineWarningMessage: String? = nil
    @StateObject private var moderationService = ContentModerationService()
    
    // New rating states
    @State private var creaminessRating: Int = 3
    @State private var chaiStrengthRating: Int = 3
    @State private var selectedFlavorNotes: Set<String> = []
    @State private var chaiType = ""
    @State private var showChaiTypeDropdown = false
    
    // 📸 Photo states
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedPhotoData: Data? = nil
    @State private var photoURL: String?
    @State private var isUploadingPhoto = false
    
    // 🎯 Gamification states
    @State private var showingBadgeEarned = false
    @State private var newlyEarnedBadges: [Badge] = []
    @State private var newlyEarnedAchievements: [Achievement] = []
    @StateObject private var gamificationService = GamificationService()
    
    // 🔒 Privacy controls
    @State private var reviewVisibility: String = "public" // "public", "friends", "private"
    @State private var showingPrivacyHelp = false
    
    private let db = Firestore.firestore()
    
    private let allChaiTypes = [
        "Masala", "Ginger", "Cardamom", "Kashmiri", 
        "Saffron", "Karak", "Adeni"
    ]
    
    private let allFlavorNotes: [FlavorNote] = [
        FlavorNote(name: "Cardamom", color: Color(hex: "#8B4513"), symbol: "leaf"), // Brown
        FlavorNote(name: "Ginger", color: Color(hex: "#FF6B35"), symbol: "flame"), // Orange
        FlavorNote(name: "Cloves", color: Color(hex: "#800020"), symbol: "circle"), // Burgundy
        FlavorNote(name: "Saffron", color: Color(hex: "#FFD700"), symbol: "star"), // Gold
        FlavorNote(name: "Fennel", color: Color(hex: "#228B22"), symbol: "drop") // Forest Green
    ]
    
    // Helper computed properties to break down complex expressions
    private var deviceFontSize: CGFloat {
        UIDevice.current.userInterfaceIdiom == .pad ? 24 : 20
    }
    
    private var deviceButtonSize: CGFloat {
        UIDevice.current.userInterfaceIdiom == .pad ? 44 : 36
    }
    
    private var totalGamificationScore: Int {
        var score = 10 // Base rating score
        
        // Detailed ratings bonus
        if creaminessRating != 3 { score += 5 }
        if chaiStrengthRating != 3 { score += 5 }
        if !selectedFlavorNotes.isEmpty { score += 5 }
        if !chaiType.isEmpty { score += 5 }
        
        // 📸 Photo bonus
        if selectedPhotoData != nil || photoURL != nil { score += 15 }
        
        // Comment bonus
        if !comment.isEmpty {
            let wordCount = comment.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
            score += min(wordCount * 2, 20) // Max 20 points for detailed comments
        }
        
        return score
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.lg) {
                    // Header
                    headerSection
                    
                    // Overall Rating
                    overallRatingSection
                    
                    // Detailed Ratings
                    detailedRatingsSection
                    
                    // Flavor Notes
                    flavorNotesSection
                    
                    // Chai Type Selection
                    chaiTypeSection
                    
                    // 📸 Photo Section
                    photoSection
                    
                    // Comment Section
                    commentSection
                    
                    // 🔒 Privacy Controls Section
                    privacyControlsSection
                    
                    // Gamification Score
                    gamificationScoreSection
                    
                    // Submit Button
                    submitButton
                }
                .padding(DesignSystem.Spacing.lg)
            }
            .background(DesignSystem.Colors.background)
            .navigationTitle("Rate Chai Spot")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onChange(of: selectedPhoto) { newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        await MainActor.run {
                            selectedPhotoData = data
                        }
                    }
                }
            }
            .sheet(isPresented: $showingBadgeEarned) {
                BadgeEarnedView(
                    badges: newlyEarnedBadges,
                    achievements: newlyEarnedAchievements,
                    onDismiss: {
                        showingBadgeEarned = false
                        dismiss()
                    }
                )
            }
            .onAppear {
                loadExistingRating()
            }
            .alert("Content Warning", isPresented: $showContentWarning) {
                Button("Edit", role: .cancel) { }
                Button("Submit Anyway", role: .destructive) {
                    submitRating()
                }
            } message: {
                Text(contentWarningMessage)
            }
            .multiFieldKeyboardDismissible()
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Text("Rate Your Chai Experience")
                .font(DesignSystem.Typography.titleLarge)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .accessibilityLabel("Rating form title")
            
            Text("Share your thoughts and help others discover great chai spots!")
                .font(DesignSystem.Typography.bodyMedium)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.large)
        .shadow(color: DesignSystem.Shadows.medium.color, radius: DesignSystem.Shadows.medium.radius, x: DesignSystem.Shadows.medium.x, y: DesignSystem.Shadows.medium.y)
    }
    
    // MARK: - Overall Rating Section
    private var overallRatingSection: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            HStack {
                Text("Overall Rating")
                    .font(DesignSystem.Typography.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(ratingValue)/5")
                    .font(DesignSystem.Typography.titleMedium)
                    .fontWeight(.bold)
                    .foregroundColor(DesignSystem.Colors.primary)
            }
            
            HStack(spacing: DesignSystem.Spacing.sm) {
                ForEach(1...5, id: \.self) { star in
                    Button(action: {
                        ratingValue = star
                    }) {
                        Image(systemName: star <= ratingValue ? "star.fill" : "star")
                            .font(.system(size: deviceButtonSize))
                            .foregroundColor(star <= ratingValue ? DesignSystem.Colors.primary : DesignSystem.Colors.textSecondary)
                    }
                    .accessibilityLabel("Rate \(star) stars")
                    .accessibilityValue(star <= ratingValue ? "Selected" : "Not selected")
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                .stroke(DesignSystem.Colors.border, lineWidth: 1)
        )
    }
    
    // MARK: - Detailed Ratings Section
    private var detailedRatingsSection: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Text("Detailed Ratings")
                .font(DesignSystem.Typography.headline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: DesignSystem.Spacing.md) {
                // Creaminess Rating
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    HStack {
                        Text("Creaminess")
                            .font(DesignSystem.Typography.bodyMedium)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Text(creaminessLabel)
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    
                    Slider(value: Binding(
                        get: { Double(creaminessRating) },
                        set: { creaminessRating = Int($0) }
                    ), in: 1...5, step: 1)
                    .accentColor(DesignSystem.Colors.creaminessRating)
                    .accessibilityLabel("Creaminess level: \(creaminessLabel)")
                    .accessibilityValue("\(creaminessRating) out of 5")
                }
                
                // Chai Strength Rating
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    HStack {
                        Text("Chai Strength")
                            .font(DesignSystem.Typography.bodyMedium)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Text(strengthLabel)
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    
                    Slider(value: Binding(
                        get: { Double(chaiStrengthRating) },
                        set: { chaiStrengthRating = Int($0) }
                    ), in: 1...5, step: 1)
                    .accentColor(DesignSystem.Colors.chaiStrengthRating)
                    .accessibilityLabel("Chai strength level: \(strengthLabel)")
                    .accessibilityValue("\(chaiStrengthRating) out of 5")
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
    
    // MARK: - Flavor Notes Section
    private var flavorNotesSection: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Text("Flavor Notes")
                .font(DesignSystem.Typography.headline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: DesignSystem.Spacing.sm) {
                ForEach(allFlavorNotes, id: \.name) { flavor in
                    Button(action: {
                        if selectedFlavorNotes.contains(flavor.name) {
                            selectedFlavorNotes.remove(flavor.name)
                        } else {
                            selectedFlavorNotes.insert(flavor.name)
                        }
                    }) {
                        HStack {
                            Image(systemName: flavor.symbol)
                                .foregroundColor(flavor.color)
                                .accessibilityHidden(true)
                            
                            Text(flavor.name)
                                .font(DesignSystem.Typography.bodyMedium)
                                .fontWeight(.medium)
                            
                            Spacer()
                            
                            if selectedFlavorNotes.contains(flavor.name) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(DesignSystem.Colors.primary)
                            }
                        }
                        .padding(DesignSystem.Spacing.md)
                        .background(selectedFlavorNotes.contains(flavor.name) ? DesignSystem.Colors.primary.opacity(0.1) : DesignSystem.Colors.cardBackground)
                        .cornerRadius(DesignSystem.CornerRadius.medium)
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                                .stroke(selectedFlavorNotes.contains(flavor.name) ? DesignSystem.Colors.primary : DesignSystem.Colors.border, lineWidth: 1)
                        )
                    }
                    .accessibilityLabel("\(flavor.name) flavor")
                    .accessibilityValue(selectedFlavorNotes.contains(flavor.name) ? "Selected" : "Not selected")
                    .accessibilityAddTraits(selectedFlavorNotes.contains(flavor.name) ? .isSelected : [])
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
    
    // MARK: - Chai Type Section
    private var chaiTypeSection: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Text("Chai Type")
                .font(DesignSystem.Typography.headline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Menu {
                ForEach(allChaiTypes, id: \.self) { type in
                    Button(type) {
                        chaiType = type
                    }
                }
            } label: {
                HStack {
                    Text(chaiType.isEmpty ? "Select chai type" : chaiType)
                        .foregroundColor(chaiType.isEmpty ? DesignSystem.Colors.textSecondary : DesignSystem.Colors.textPrimary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .accessibilityHidden(true)
                }
                .padding(DesignSystem.Spacing.md)
                .background(DesignSystem.Colors.cardBackground)
                .cornerRadius(DesignSystem.CornerRadius.medium)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                        .stroke(DesignSystem.Colors.border, lineWidth: 1)
                )
            }
            .accessibilityLabel("Select chai type")
            .accessibilityHint("Double tap to open chai type options")
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                .stroke(DesignSystem.Colors.border, lineWidth: 1)
        )
    }
    
    // MARK: - Photo Section
    private var photoSection: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            HStack {
                Text("📸 Add Photo")
                    .font(DesignSystem.Typography.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if selectedPhotoData != nil {
                    Text("+15 points")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                }
            }
            
            VStack(spacing: DesignSystem.Spacing.sm) {
                if let photoData = selectedPhotoData,
                   let uiImage = UIImage(data: photoData) {
                    // Display selected photo
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 200)
                        .clipped()
                        .cornerRadius(DesignSystem.CornerRadius.medium)
                        .overlay(
                            Button(action: {
                                selectedPhotoData = nil
                                selectedPhoto = nil
                                photoURL = nil
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .background(Color.black.opacity(0.6))
                                    .clipShape(Circle())
                            }
                            .padding(8),
                            alignment: .topTrailing
                        )
                } else {
                    // Photo picker button
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        VStack(spacing: DesignSystem.Spacing.sm) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 40))
                                .foregroundColor(DesignSystem.Colors.accent)
                            
                            Text("Add a photo of your chai")
                                .font(DesignSystem.Typography.bodyMedium)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                            
                            Text("+15 bonus points!")
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(.green)
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(DesignSystem.Spacing.xl)
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
            
            Text("Photos help other users discover great chai spots!")
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .iPadCardStyle()
    }
    
    // MARK: - Comment Section
    private var commentSection: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            HStack {
                Text("Comment")
                    .font(DesignSystem.Typography.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(comment.count)/500")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(comment.count > 450 ? DesignSystem.Colors.warning : DesignSystem.Colors.textSecondary)
            }
            
            TextEditor(text: $comment)
                .font(DesignSystem.Typography.bodyMedium)
                .frame(minHeight: 100)
                .padding(DesignSystem.Spacing.md)
                .background(DesignSystem.Colors.cardBackground)
                .cornerRadius(DesignSystem.CornerRadius.medium)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                        .stroke(DesignSystem.Colors.border, lineWidth: 1)
                )
                .accessibilityLabel("Write your comment")
                .accessibilityHint("Share your thoughts about this chai spot")
            
            if let warning = inlineWarningMessage {
                Text(warning)
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.warning)
                    .frame(maxWidth: .infinity, alignment: .leading)
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
    
    // MARK: - Privacy Controls Section
    private var privacyControlsSection: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            HStack {
                Image(systemName: "lock.shield.fill")
                    .foregroundColor(DesignSystem.Colors.primary)
                
                Text("Review Privacy")
                    .font(DesignSystem.Typography.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: { showingPrivacyHelp = true }) {
                    Image(systemName: "questionmark.circle")
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }
            
            Text("Control who can see your review")
                .font(DesignSystem.Typography.bodyMedium)
                .foregroundColor(DesignSystem.Colors.textSecondary)
            
            VStack(spacing: DesignSystem.Spacing.sm) {
                PrivacyOptionRow(
                    title: "Public",
                    description: "Everyone can see your review",
                    icon: "globe",
                    isSelected: reviewVisibility == "public",
                    action: { reviewVisibility = "public" }
                )
                
                PrivacyOptionRow(
                    title: "Friends Only",
                    description: "Only your friends can see your review",
                    icon: "person.2.fill",
                    isSelected: reviewVisibility == "friends",
                    action: { reviewVisibility = "friends" }
                )
                
                PrivacyOptionRow(
                    title: "Private",
                    description: "Only you can see your review",
                    icon: "lock.fill",
                    isSelected: reviewVisibility == "private",
                    action: { reviewVisibility = "private" }
                )
            }
            
            // Show current privacy default
            if let userProfile = sessionStore.userProfile,
               let privacyDefaults = userProfile.privacyDefaults {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(DesignSystem.Colors.info)
                    
                    Text("Your default setting is: \(privacyDefaults.reviewsDefaultVisibility.capitalized)")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    
                    Spacer()
                }
                .padding(.top, DesignSystem.Spacing.sm)
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                .stroke(DesignSystem.Colors.border, lineWidth: 1)
        )
        .iPadCardStyle()
        .alert("Privacy Help", isPresented: $showingPrivacyHelp) {
            Button("OK") { }
        } message: {
            Text("• Public: Your review appears in community feeds and spot details\n• Friends Only: Only your friends can see your review\n• Private: Only you can see your review for personal tracking")
        }
    }
    
    // MARK: - Gamification Score Section
    private var gamificationScoreSection: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            HStack {
                Text("🎮 Gamification Score")
                    .font(DesignSystem.Typography.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(totalGamificationScore) pts")
                    .font(DesignSystem.Typography.titleMedium)
                    .fontWeight(.bold)
                    .foregroundColor(DesignSystem.Colors.primary)
            }
            
            VStack(spacing: DesignSystem.Spacing.sm) {
                scoreRow("Base rating", 10, isEarned: true)
                scoreRow("Detailed ratings", 20, isEarned: creaminessRating != 3 || chaiStrengthRating != 3 || !selectedFlavorNotes.isEmpty || !chaiType.isEmpty)
                scoreRow("Detailed comment", 20, isEarned: !comment.isEmpty)
                scoreRow("Photo bonus", 15, isEarned: selectedPhotoData != nil)
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
    
    // MARK: - Submit Button Section
    private var submitButton: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Button(action: {
                validateAndSubmit()
            }) {
                HStack {
                    if isSubmitting {
                        ProgressView()
                            .scaleEffect(0.8)
                            .accessibilityHidden(true)
                    } else {
                        Image(systemName: "star.fill")
                            .accessibilityHidden(true)
                    }
                    
                    Text(isSubmitting ? "Submitting..." : "Submit Rating")
                        .font(DesignSystem.Typography.bodyMedium)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(minHeight: DesignSystem.Layout.minTouchTarget)
                .background(isSubmitting ? DesignSystem.Colors.textSecondary : DesignSystem.Colors.primary)
                .cornerRadius(DesignSystem.CornerRadius.medium)
            }
            .disabled(isSubmitting)
            .accessibilityLabel("Submit rating")
            .accessibilityHint("Double tap to submit your rating")
            
            if isSubmitting {
                Text("Please wait while we process your rating...")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(DesignSystem.Spacing.lg)
    }
    
    // MARK: - Helper Views
    private func scoreRow(_ title: String, _ maxPoints: Int, isEarned: Bool) -> some View {
        HStack {
            Text(title)
                .font(DesignSystem.Typography.bodyMedium)
                .foregroundColor(isEarned ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textSecondary)
            
            Spacer()
            
            if isEarned {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(DesignSystem.Colors.success)
                    .accessibilityHidden(true)
                
                Text("+\(maxPoints)")
                    .font(DesignSystem.Typography.bodyMedium)
                    .fontWeight(.semibold)
                    .foregroundColor(DesignSystem.Colors.success)
            } else {
                Text("+\(maxPoints)")
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
        }
    }
    
    // MARK: - Helper Functions
    private var creaminessLabel: String {
        switch creaminessRating {
        case 1: return "Light"
        case 2: return "Mild"
        case 3: return "Medium"
        case 4: return "Rich"
        case 5: return "Very Rich"
        default: return "Medium"
        }
    }
    
    private var strengthLabel: String {
        switch chaiStrengthRating {
        case 1: return "Mild"
        case 2: return "Light"
        case 3: return "Medium"
        case 4: return "Strong"
        case 5: return "Very Strong"
        default: return "Medium"
        }
    }
    
    private func loadExistingRating() {
        guard let existing = existingRating else { return }
        
        ratingValue = existing.value
        comment = existing.comment ?? ""
        creaminessRating = existing.creaminessRating ?? 3
        chaiStrengthRating = existing.chaiStrengthRating ?? 3
        selectedFlavorNotes = Set(existing.flavorNotes ?? [])
        chaiType = existing.chaiType ?? ""
    }
    
    private func validateAndSubmit() {
        // Clear any previous warnings
        inlineWarningMessage = nil
        
        // Basic validation
        guard ratingValue > 0 else {
            inlineWarningMessage = "Please select an overall rating"
            return
        }
        
        // Content moderation check
        if !comment.isEmpty {
            let (isAppropriate, _) = moderationService.filterContent(comment)
            if !isAppropriate {
                contentWarningMessage = "Your comment may contain inappropriate content. Please review and edit if necessary."
                showContentWarning = true
                return
            }
        }
        
        submitRating()
    }
    
    private func submitRating() {
        isSubmitting = true
        
        Task {
            do {
                // Photo functionality temporarily disabled due to FirebaseStorage dependency
                let finalPhotoURL = photoURL
                
                let ratingData: [String: Any] = [
                    "spotId": spotId,
                    "spotName": spotName,
                    "spotAddress": spotAddress,
                    "userId": sessionStore.userProfile?.id ?? "",
                    "username": sessionStore.userProfile?.displayName ?? "Anonymous",
                    "rating": ratingValue,
                    "comment": comment.isEmpty ? nil : comment,
                    "creaminessRating": creaminessRating,
                    "chaiStrengthRating": chaiStrengthRating,
                    "flavorNotes": Array(selectedFlavorNotes),
                    "chaiType": chaiType.isEmpty ? nil : chaiType,
                    "photoURL": finalPhotoURL, // Use uploaded photo URL
                    "hasPhoto": finalPhotoURL != nil,
                    "timestamp": FieldValue.serverTimestamp(),
                    "gamificationScore": totalGamificationScore,
                    "visibility": reviewVisibility // 🔒 Add privacy setting
                ]
                
                print("📝 Submitting rating with data: spotId=\(spotId), spotName=\(spotName), spotAddress=\(spotAddress)")
                
                if let existing = existingRating {
                    // Update existing rating
                    try await db.collection("ratings").document(existing.id ?? "").updateData(ratingData)
                    print("✅ Updated existing rating for spot: \(spotName)")
                } else {
                    // Create new rating
                    try await db.collection("ratings").addDocument(data: ratingData)
                    print("✅ Created new rating for spot: \(spotName)")
                }
                
                // Check for new badges and achievements
                let newBadges = await gamificationService.checkAndAwardBadges(
                    userProfile: sessionStore.userProfile ?? UserProfile(id: "", uid: "", displayName: "", email: ""),
                    newRating: Rating(
                        spotId: spotId,
                        userId: sessionStore.userProfile?.id ?? "",
                        username: sessionStore.userProfile?.displayName ?? "",
                        value: ratingValue,
                        comment: comment.isEmpty ? nil : comment,
                        creaminessRating: creaminessRating,
                        chaiStrengthRating: chaiStrengthRating,
                        flavorNotes: Array(selectedFlavorNotes),
                        chaiType: chaiType.isEmpty ? nil : chaiType,
                        photoURL: finalPhotoURL
                    )
                )
                let newAchievements = await gamificationService.checkAndAwardAchievements(
                    userProfile: sessionStore.userProfile ?? UserProfile(id: "", uid: "", displayName: "", email: ""),
                    newRating: Rating(
                        spotId: spotId,
                        userId: sessionStore.userProfile?.id ?? "",
                        username: sessionStore.userProfile?.displayName ?? "",
                        value: ratingValue,
                        comment: comment.isEmpty ? nil : comment,
                        creaminessRating: creaminessRating,
                        chaiStrengthRating: chaiStrengthRating,
                        flavorNotes: Array(selectedFlavorNotes),
                        chaiType: chaiType.isEmpty ? nil : chaiType,
                        photoURL: finalPhotoURL
                    )
                )
                
                await MainActor.run {
                    isSubmitting = false
                    
                    if !newBadges.isEmpty || !newAchievements.isEmpty {
                        newlyEarnedBadges = newBadges
                        newlyEarnedAchievements = newAchievements
                        showingBadgeEarned = true
                    } else {
                        onComplete()
                        dismiss()
                    }
                }
                
                // Post notification for rating update
                NotificationCenter.default.post(name: .ratingUpdated, object: nil)
                
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    inlineWarningMessage = "Failed to submit rating: \(error.localizedDescription)"
                }
            }
        }
    }
    

    
    // MARK: - Helper Functions
    
    private func performSubmission() {
        let ratingData: [String: Any] = [
            "spotId": spotId,
            "userId": sessionStore.currentUser?.uid ?? "",
            "value": ratingValue,
            "comment": comment.isEmpty ? nil : comment,
            "creaminessRating": creaminessRating,
            "chaiStrengthRating": chaiStrengthRating,
            "flavorNotes": Array(selectedFlavorNotes),
            "chaiType": chaiType.isEmpty ? nil : chaiType,
            "photoURL": photoURL,
            "timestamp": FieldValue.serverTimestamp(),
            "gamificationScore": totalGamificationScore
        ]
        
        if let existingRating = existingRating {
            // Update existing rating
            updateExistingRating(ratingData)
        } else {
            // Create new rating
            createNewRating(ratingData)
        }
    }
    
    private func createNewRating(_ ratingData: [String: Any]) {
        let ratingRef = db.collection("ratings").document()
        
        ratingRef.setData(ratingData) { error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Error creating rating: \(error.localizedDescription)")
                    self.isSubmitting = false
                } else {
                    print("✅ Rating created successfully")
                    self.handleRatingSuccess()
                }
            }
        }
    }
    
    private func updateExistingRating(_ ratingData: [String: Any]) {
        guard let existingRating = existingRating else { return }
        
        db.collection("ratings").document(existingRating.id ?? "").updateData(ratingData) { error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Error updating rating: \(error.localizedDescription)")
                    self.isSubmitting = false
                } else {
                    print("✅ Rating updated successfully")
                    self.handleRatingSuccess()
                }
            }
        }
    }
    
    private func handleRatingSuccess() {
        // Check for new badges and achievements
        Task {
            let newRating = Rating(
                id: nil,
                spotId: spotId,
                userId: sessionStore.currentUser?.uid ?? "",
                value: ratingValue,
                comment: comment.isEmpty ? nil : comment,
                creaminessRating: creaminessRating,
                chaiStrengthRating: chaiStrengthRating,
                flavorNotes: Array(selectedFlavorNotes),
                chaiType: chaiType.isEmpty ? nil : chaiType,
                photoURL: photoURL
            )
            
            let userProfile = await getUserProfile()
            
            let newBadges = await gamificationService.checkAndAwardBadges(
                userProfile: userProfile,
                newRating: newRating
            )
            
            let newAchievements = await gamificationService.checkAndAwardAchievements(
                userProfile: userProfile,
                newRating: newRating
            )
            
            await MainActor.run {
                if !newBadges.isEmpty || !newAchievements.isEmpty {
                    newlyEarnedBadges = newBadges
                    newlyEarnedAchievements = newAchievements
                    showingBadgeEarned = true
                } else {
                    onComplete()
                    dismiss()
                }
            }
        }
    }
    
    private func getUserProfile() async -> UserProfile {
        guard let userId = sessionStore.currentUser?.uid else {
            return UserProfile(uid: "", displayName: "", email: "")
        }
        
        do {
            let document = try await db.collection("users").document(userId).getDocument()
            if let data = document.data() {
                return UserProfile(
                    id: document.documentID,
                    uid: data["uid"] as? String ?? "",
                    displayName: data["displayName"] as? String ?? "",
                    email: data["email"] as? String ?? "",
                    photoURL: data["photoURL"] as? String,
                    friends: data["friends"] as? [String],
                    incomingRequests: data["incomingRequests"] as? [String],
                    outgoingRequests: data["outgoingRequests"] as? [String],
                    bio: data["bio"] as? String,
                    hasTasteSetup: data["hasTasteSetup"] as? Bool ?? false,
                    tasteVector: data["tasteVector"] as? [Int],
                    topTasteTags: data["topTasteTags"] as? [String],
                    badges: data["badges"] as? [String] ?? [],
                    currentStreak: data["currentStreak"] as? Int ?? 0,
                    longestStreak: data["longestStreak"] as? Int ?? 0,
                    lastReviewDate: data["lastReviewDate"] as? Date,
                    totalReviews: data["totalReviews"] as? Int ?? 0,
                    spotsVisited: data["spotsVisited"] as? Int ?? 0,
                    challengeProgress: data["challengeProgress"] as? [String: Int] ?? [:],
                    achievements: data["achievements"] as? [String: Date] ?? [:],
                    totalScore: data["totalScore"] as? Int ?? 0
                )
            }
        } catch {
            print("❌ Error fetching user profile: \(error.localizedDescription)")
        }
        
        return UserProfile(uid: "", displayName: "", email: "")
    }
}

// MARK: - Badge Earned View
struct BadgeEarnedView: View {
    let badges: [Badge]
    let achievements: [Achievement]
    let onDismiss: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: DesignSystem.Spacing.lg) {
                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.xl) {
                        // Header
                        VStack(spacing: DesignSystem.Spacing.md) {
                            Image(systemName: "trophy.fill")
                                .font(.system(size: 64))
                                .foregroundColor(DesignSystem.Colors.primary)
                                .accessibilityHidden(true)
                            
                            Text("Congratulations!")
                                .font(DesignSystem.Typography.titleLarge)
                                .fontWeight(.bold)
                                .multilineTextAlignment(.center)
                            
                            Text("You've earned new rewards!")
                                .font(DesignSystem.Typography.bodyMedium)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        
                        // Badges
                        if !badges.isEmpty {
                            VStack(spacing: DesignSystem.Spacing.md) {
                                Text("🎖️ New Badges")
                                    .font(DesignSystem.Typography.headline)
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: DesignSystem.Spacing.md) {
                                    ForEach(badges, id: \.id) { badge in
                                        BadgeView(badge: badge)
                                    }
                                }
                            }
                        }
                        
                        // Achievements
                        if !achievements.isEmpty {
                            VStack(spacing: DesignSystem.Spacing.md) {
                                Text("🏆 New Achievements")
                                    .font(DesignSystem.Typography.headline)
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: DesignSystem.Spacing.md) {
                                    ForEach(achievements, id: \.id) { achievement in
                                        AchievementView(achievement: achievement)
                                    }
                                }
                            }
                        }
                    }
                    .padding(DesignSystem.Spacing.lg)
                }
                
                // Continue Button
                Button(action: onDismiss) {
                    Text("Continue")
                        .font(DesignSystem.Typography.bodyMedium)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: DesignSystem.Layout.minTouchTarget)
                        .background(DesignSystem.Colors.primary)
                        .cornerRadius(DesignSystem.CornerRadius.medium)
                }
                .accessibilityLabel("Continue to app")
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.bottom, DesignSystem.Spacing.lg)
            }
            .navigationTitle("Rewards Earned")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onDismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Badge View Component
struct BadgeView: View {
    let badge: Badge
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: badge.iconName)
                .font(.system(size: 32))
                .foregroundColor(DesignSystem.Colors.primary)
                .accessibilityHidden(true)
            
            Text(badge.name)
                .font(DesignSystem.Typography.caption)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(width: 80)
        .padding(DesignSystem.Spacing.sm)
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                .stroke(DesignSystem.Colors.border, lineWidth: 1)
        )
    }
}

// MARK: - Achievement View Component
struct AchievementView: View {
    let achievement: Achievement
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: "star.fill")
                .font(.system(size: 32))
                .foregroundColor(DesignSystem.Colors.secondary)
                .accessibilityHidden(true)
            
            Text(achievement.name)
                .font(DesignSystem.Typography.caption)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(width: 80)
        .padding(DesignSystem.Spacing.sm)
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                .stroke(DesignSystem.Colors.border, lineWidth: 1)
        )
    }
}

// MARK: - Preview
struct SubmitRatingView_Previews: PreviewProvider {
    static var previews: some View {
        SubmitRatingView(
            spotId: "preview",
            spotName: "Preview Spot",
            spotAddress: "123 Preview St",
            existingRating: nil,
            onComplete: {}
        )
        .environmentObject(SessionStore())
    }
}
