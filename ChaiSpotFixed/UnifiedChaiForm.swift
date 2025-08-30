import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore
import PhotosUI
import MapKit

// Notification names for rating updates
extension Notification.Name {
    static let ratingUpdated = Notification.Name("ratingUpdated")
    static let spotsUpdated = Notification.Name("spotsUpdated")
    static let reactionUpdated = Notification.Name("reactionUpdated")
    static let commentEngagementUpdated = Notification.Name("commentEngagementUpdated")
    static let reviewVisibilityChanged = Notification.Name("reviewVisibilityChanged")
}

struct UnifiedChaiForm: View {
    // MARK: - Properties
    let isAddingNewSpot: Bool
    let existingSpot: ChaiSpot? // For rating existing spots
    var coordinate: CLLocationCoordinate2D? // For new spots
    let onComplete: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var sessionStore: SessionStore
    
    // Location states (for new spots)
    @State private var name = ""
    @State private var address = ""

    @State private var isLoadingAddress = false
    @State private var resolvedCoordinate: CLLocationCoordinate2D? = nil
    
    // Rating states
    @State private var ratingValue: Int = 3
    @State private var comment: String = ""
    @State private var isSubmitting = false
    @State private var showContentWarning = false
    @State private var contentWarningMessage = ""
    @State private var inlineWarningMessage: String? = nil
    @StateObject private var moderationService = ContentModerationService()
    
    // Detailed rating states
    @State private var creaminessRating: Int = 3
    @State private var chaiStrengthRating: Int = 3
    @State private var selectedFlavorNotes: Set<String> = []
    @State private var chaiType = ""
    @State private var showChaiTypeDropdown = false
    
    // Photo states
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedPhotoData: Data? = nil
    @State private var photoURL: String? = nil
    @State private var isUploadingPhoto = false
    
    // Gamification states
    @State private var showingBadgeEarned = false
    @State private var newlyEarnedBadges: [Badge] = []
    @State private var newlyEarnedAchievements: [Achievement] = []
    @StateObject private var gamificationService = GamificationService()
    
    // Privacy controls
    @State private var reviewVisibility: String = "public"
    @State private var showingPrivacyHelp = false
    
    // Autocomplete for new spots
    @StateObject private var autoModel = AutocompleteModel()
    @State private var showNameDropdown = false
    @State private var justSelectedName = false
    
    private let db = Firestore.firestore()
    
    private let allChaiTypes = [
        "Masala", "Ginger", "Cardamom", "Kashmiri", 
        "Saffron", "Karak", "Adeni", "Tulsi", "Lemongrass",
        "Cinnamon", "Black Pepper", "Fennel", "Mint",
        "Rose", "Vanilla", "Honey", "Jaggery", "Sugar-free"
    ]
    
    private let allFlavorNotes: [FlavorNote] = [
        FlavorNote(name: "Cardamom", color: Color(hex: "#8B4513"), symbol: "leaf"),
        FlavorNote(name: "Ginger", color: Color(hex: "#FF6B35"), symbol: "flame"),
        FlavorNote(name: "Cloves", color: Color(hex: "#800020"), symbol: "circle"),
        FlavorNote(name: "Saffron", color: Color(hex: "#FFD700"), symbol: "star"),
        FlavorNote(name: "Fennel", color: Color(hex: "#228B22"), symbol: "drop")
    ]
    
    // MARK: - Computed Properties
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
        
        // Photo bonus
        if selectedPhotoData != nil || photoURL != nil { score += 15 }
        
        // Comment bonus
        if !comment.isEmpty {
            let wordCount = comment.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
            score += min(wordCount * 2, 20)
        }
        
        return score
    }
    
    private var formTitle: String {
        isAddingNewSpot ? "Add New Chai Spot" : "Rate Your Chai Experience"
    }
    
    private var submitButtonText: String {
        isAddingNewSpot ? "Add Chai Spot" : "Submit Rating"
    }
    
    // MARK: - Body
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.lg) {
                    // Header
                    headerSection
                    
                    // Location Section (different for new vs existing)
                    locationSection
                    
                    // Overall Rating
                    overallRatingSection
                    
                    // Detailed Ratings
                    detailedRatingsSection
                    
                    // Flavor Notes
                    flavorNotesSection
                    
                    // Chai Type Selection
                    chaiTypeSection
                    
                    // Photo Section
                    photoSection
                    
                    // Comment Section
                    commentSection
                    
                    // Privacy Controls Section
                    privacyControlsSection
                    
                    // Gamification Score
                    gamificationScoreSection
                    
                    // Submit Button
                    submitButton
                }
                .padding(DesignSystem.Spacing.lg)
            }
            .background(DesignSystem.Colors.background)
            .navigationTitle(formTitle)
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
                setupForm()
            }
            .alert("Content Warning", isPresented: $showContentWarning) {
                Button("Edit", role: .cancel) { }
                Button("Submit Anyway", role: .destructive) {
                    submitForm()
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
            Text(formTitle)
                .font(DesignSystem.Typography.titleLarge)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .accessibilityLabel("Form title")
            
            // Show spot name when rating existing location
            if !isAddingNewSpot, let existingSpot = existingSpot {
                Text(existingSpot.name)
                    .font(DesignSystem.Typography.titleMedium)
                    .fontWeight(.semibold)
                    .foregroundColor(DesignSystem.Colors.primary)
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.vertical, DesignSystem.Spacing.sm)
                    .background(DesignSystem.Colors.primary.opacity(0.1))
                    .cornerRadius(DesignSystem.CornerRadius.medium)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                            .stroke(DesignSystem.Colors.primary.opacity(0.3), lineWidth: 1)
                    )
            }
            
            Text(isAddingNewSpot ? 
                 "Add a new chai spot to help others discover great places!" :
                 "Share your thoughts and help others discover great chai spots!")
                .font(DesignSystem.Typography.bodyMedium)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.large)
        .shadow(color: DesignSystem.Shadows.medium.color, radius: DesignSystem.Shadows.medium.radius, x: DesignSystem.Shadows.medium.x, y: DesignSystem.Shadows.medium.y)
    }
    
    // MARK: - Location Section
    private var locationSection: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            HStack {
                Image(systemName: "location.circle.fill")
                    .foregroundColor(DesignSystem.Colors.primary)
                    .font(.title2)
                
                Text(isAddingNewSpot ? "New Chai Spot Details" : "Chai Spot Location")
                    .font(DesignSystem.Typography.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            if isAddingNewSpot {
                // Editable location fields for new spots
                newSpotLocationFields
            } else {
                // Read-only location display for existing spots
                existingSpotLocationDisplay
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
    
    // MARK: - New Spot Location Fields
    private var newSpotLocationFields: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            // Shop Name with autocomplete
            TextField("Shop Name", text: $name, onEditingChanged: { began in
                if began && !justSelectedName {
                    showNameDropdown = !name.isEmpty
                    autoModel.completer.queryFragment = name
                }
                if !began {
                    justSelectedName = false
                }
            })
            .padding(8)
            .background(Color(white: 0.95))
            .cornerRadius(6)
            .onChange(of: name) { newValue in
                if !justSelectedName {
                    showNameDropdown = !newValue.isEmpty
                    autoModel.completer.queryFragment = newValue
                }
            }
            
            // Autocomplete suggestions
            if showNameDropdown && !autoModel.results.isEmpty {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(autoModel.results, id: \.self) { completion in
                            Button(action: {
                                let full = completion.title + " " + completion.subtitle
                                justSelectedName = true
                                name = completion.title
                                showNameDropdown = false
                                autoModel.results = []
                                geocodePlace(named: full)
                                
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    justSelectedName = false
                                }
                            }) {
                                VStack(alignment: .leading) {
                                    Text(completion.title)
                                    Text(completion.subtitle)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            Divider()
                        }
                    }
                }
                .frame(maxHeight: 150)
                .background(Color.white)
                .cornerRadius(6)
                .shadow(radius: 2)
                .padding(.horizontal, -16)
            }
            
            // Address field
            HStack {
                TextField("Address", text: $address)
                if isLoadingAddress {
                    ProgressView().scaleEffect(0.8)
                }
            }
            
            // Coordinate display
            if let coord = resolvedCoordinate ?? coordinate {
                Text("📍 Location: \(coord.latitude, specifier: "%.4f"), \(coord.longitude, specifier: "%.4f")")
                    .font(.caption)
                    .foregroundColor(.green)
            } else {
                Text("❌ No location selected yet")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }
    
    // MARK: - Existing Spot Location Display
    private var existingSpotLocationDisplay: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(existingSpot?.name ?? "Unknown Spot")
                        .font(DesignSystem.Typography.titleMedium)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    
                    Text(existingSpot?.address ?? "No address")
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    
                    if let coord = existingSpot?.coordinate {
                        Text("📍 \(coord.latitude, specifier: "%.4f"), \(coord.longitude, specifier: "%.4f")")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(DesignSystem.Colors.success)
                    .font(.title2)
            }
            .padding(DesignSystem.Spacing.md)
            .background(DesignSystem.Colors.success.opacity(0.1))
            .cornerRadius(DesignSystem.CornerRadius.medium)
        }
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
                        Image(systemName: isAddingNewSpot ? "plus.circle.fill" : "star.fill")
                            .accessibilityHidden(true)
                    }
                    
                    Text(isSubmitting ? "Submitting..." : submitButtonText)
                        .font(DesignSystem.Typography.bodyMedium)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(minHeight: DesignSystem.Layout.minTouchTarget)
                .background(isSubmitting ? DesignSystem.Colors.textSecondary : DesignSystem.Colors.primary)
                .cornerRadius(DesignSystem.CornerRadius.medium)
            }
            .disabled(isSubmitting || !canSubmit)
            .accessibilityLabel(submitButtonText)
            .accessibilityHint("Double tap to submit")
            
            if isSubmitting {
                Text("Please wait while we process your submission...")
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
    
    private var canSubmit: Bool {
        if isAddingNewSpot {
            return !name.isEmpty && !address.isEmpty && (resolvedCoordinate != nil || coordinate != nil)
        } else {
            return ratingValue > 0
        }
    }
    
    private func setupForm() {
        if !isAddingNewSpot, let existingSpot = existingSpot {
            // Pre-populate with existing spot data
            name = existingSpot.name
            address = existingSpot.address
            // Use existing spot coordinate
        }
        
        // Set up autocomplete for new spots
        if isAddingNewSpot {
            autoModel.completer.delegate = autoModel
        }
    }
    
    private func validateAndSubmit() {
        // Clear any previous warnings
        inlineWarningMessage = nil
        
        // Basic validation
        if isAddingNewSpot {
            guard !name.isEmpty else {
                inlineWarningMessage = "Please enter a shop name"
                return
            }
            guard !address.isEmpty else {
                inlineWarningMessage = "Please enter an address"
                return
            }
            guard resolvedCoordinate != nil || coordinate != nil else {
                inlineWarningMessage = "Please select a location"
                return
            }
        } else {
            guard ratingValue > 0 else {
                inlineWarningMessage = "Please select an overall rating"
                return
            }
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
        
        submitForm()
    }
    
    private func submitForm() {
        isSubmitting = true
        
        Task {
            do {
                if isAddingNewSpot {
                    // Handle adding new spot
                    await addNewChaiSpot()
                } else {
                    // Handle rating existing spot
                    await submitRating()
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    inlineWarningMessage = "Failed to submit: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func addNewChaiSpot() async {
        // Implementation for adding new spot
        // This would integrate with your existing AddChaiSpotForm logic
        print("Adding new chai spot: \(name)")
        
        await MainActor.run {
            isSubmitting = false
            onComplete()
            dismiss()
        }
    }
    
    private func submitRating() async {
        // Implementation for submitting rating
        // This would integrate with your existing SubmitRatingView logic
        print("Submitting rating for spot: \(existingSpot?.name ?? "Unknown")")
        
        await MainActor.run {
            isSubmitting = false
            onComplete()
            dismiss()
        }
    }
    
    // Reverse lookup the selected place into an address & coordinate
    private func geocodePlace(named full: String) {
        isLoadingAddress = true
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = full
        MKLocalSearch(request: request).start { response, _ in
            DispatchQueue.main.async {
                isLoadingAddress = false
                if let coord = response?.mapItems.first?.placemark.coordinate {
                    resolvedCoordinate = coord
                    address = full
                } else {
                    address = full
                }
            }
        }
    }
}

// MARK: - Privacy Option Row Component


// MARK: - Preview
struct UnifiedChaiForm_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Preview for adding new spot
            UnifiedChaiForm(
                isAddingNewSpot: true,
                existingSpot: nil,
                coordinate: CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060),
                onComplete: {}
            )
            .environmentObject(SessionStore())
            .previewDisplayName("Add New Spot")
            
            // Preview for rating existing spot
            UnifiedChaiForm(
                isAddingNewSpot: false,
                existingSpot: ChaiSpot(
                    id: "preview",
                    name: "Preview Chai Spot",
                    address: "123 Preview St",
                    latitude: 40.7128,
                    longitude: -74.0060,
                    chaiTypes: ["Masala"],
                    averageRating: 4.2,
                    ratingCount: 15
                ),
                coordinate: nil,
                onComplete: {}
            )
            .environmentObject(SessionStore())
            .previewDisplayName("Rate Existing Spot")
        }
    }
}
