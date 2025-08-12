import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore

// Notification names for rating updates
extension Notification.Name {
    static let ratingUpdated = Notification.Name("ratingUpdated")
}

struct SubmitRatingView: View {
    let spotId: String
    let existingRating: Rating?
    let onComplete: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
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
    
    private func creaminessColor(for index: Int) -> Color {
        index <= creaminessRating ? DesignSystem.Colors.creaminessRating : DesignSystem.Colors.border
    }
    
    private func creaminessBackground(for index: Int) -> some View {
        Circle()
            .fill(index <= creaminessRating ? DesignSystem.Colors.creaminessRating.opacity(0.1) : Color.clear)
    }
    
    private func creaminessOverlay(for index: Int) -> some View {
        Circle()
            .stroke(index <= creaminessRating ? DesignSystem.Colors.creaminessRating : DesignSystem.Colors.border, lineWidth: 1)
    }
    
    private func strengthColor(for index: Int) -> Color {
        index <= chaiStrengthRating ? DesignSystem.Colors.chaiStrengthRating : DesignSystem.Colors.border
    }
    
    private func strengthBackground(for index: Int) -> some View {
        Circle()
            .fill(index <= chaiStrengthRating ? DesignSystem.Colors.chaiStrengthRating.opacity(0.1) : Color.clear)
    }
    
    private func strengthOverlay(for index: Int) -> some View {
        Circle()
            .stroke(index <= chaiStrengthRating ? DesignSystem.Colors.chaiStrengthRating : DesignSystem.Colors.border, lineWidth: 1)
    }
    
    // Helper computed properties for complex expressions
    private var chaiTypeButtonOverlay: some View {
        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
            .stroke(DesignSystem.Colors.border, lineWidth: 1)
    }
    
    private var chaiTypeDropdownContent: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            ForEach(allChaiTypes, id: \.self) { type in
                Button(action: {
                    chaiType = type
                    showChaiTypeDropdown = false
                }) {
                    HStack {
                        Image(systemName: "checkmark")
                            .foregroundColor(chaiType == type ? .white : .clear)
                        Text(type)
                            .foregroundColor(chaiType == type ? .white : .black)
                    }
                    .padding(.vertical, DesignSystem.Spacing.xs)
                    .padding(.horizontal, DesignSystem.Spacing.sm)
                    .background(chaiType == type ? DesignSystem.Colors.primary : DesignSystem.Colors.border)
                    .cornerRadius(DesignSystem.CornerRadius.small)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.vertical, DesignSystem.Spacing.xs)
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .background(DesignSystem.Colors.border)
        .cornerRadius(DesignSystem.CornerRadius.small)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                .stroke(DesignSystem.Colors.border, lineWidth: 1)
        )
    }
    
    private var flavorNotesGridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible()), count: UIDevice.current.userInterfaceIdiom == .pad ? 3 : 2)
    }
    
    private func flavorNoteButton(for note: FlavorNote) -> some View {
        Button(action: {
            if selectedFlavorNotes.contains(note.name) {
                selectedFlavorNotes.remove(note.name)
            } else {
                selectedFlavorNotes.insert(note.name)
            }
        }) {
            HStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: selectedFlavorNotes.contains(note.name) ? note.symbol + ".fill" : note.symbol)
                    .foregroundColor(selectedFlavorNotes.contains(note.name) ? .white : note.color)
                    .font(.system(size: flavorNoteIconSize))
                    .frame(width: 16, height: 16)
                Text(note.name)
                    .font(DesignSystem.Typography.bodySmall)
                    .foregroundColor(selectedFlavorNotes.contains(note.name) ? .white : note.color)
                    .fontWeight(selectedFlavorNotes.contains(note.name) ? .semibold : .regular)
            }
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .padding(.vertical, DesignSystem.Spacing.xs)
            .background(selectedFlavorNotes.contains(note.name) ? note.color : Color.clear)
            .cornerRadius(DesignSystem.CornerRadius.small)
            .overlay(flavorNoteOverlay(for: note))
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var flavorNoteIconSize: CGFloat {
        UIDevice.current.userInterfaceIdiom == .pad ? 16 : 14
    }
    
    private func flavorNoteOverlay(for note: FlavorNote) -> some View {
        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
            .stroke(selectedFlavorNotes.contains(note.name) ? note.color : note.color.opacity(0.6), lineWidth: 1)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Your Rating")) {
                    Stepper("Rating: \(ratingValue)★", value: $ratingValue, in: 1...5)
                }
                
                Section(header: Text("Creaminess Rating")) {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        HStack {
                            Text("How creamy is the chai?")
                                .font(DesignSystem.Typography.bodyMedium)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                            Spacer()
                            Text("\(creaminessRating)/5")
                                .font(DesignSystem.Typography.bodyMedium)
                                .fontWeight(.semibold)
                                .foregroundColor(DesignSystem.Colors.creaminessRating)
                        }
                        
                        HStack(spacing: DesignSystem.Spacing.sm) {
                            ForEach(1..<6) { i in
                                Button(action: { creaminessRating = i }) {
                                    Image(systemName: i <= creaminessRating ? "drop.fill" : "drop")
                                        .foregroundColor(creaminessColor(for: i))
                                        .font(.system(size: deviceFontSize))
                                        .frame(width: deviceButtonSize, height: deviceButtonSize)
                                        .background(creaminessBackground(for: i))
                                        .overlay(creaminessOverlay(for: i))
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        
                        HStack {
                            Text("Watery")
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                            Spacer()
                            Text("Creamy")
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                    }
                }
                
                Section(header: Text("Chai Strength Rating")) {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        HStack {
                            Text("How strong is the chai flavor?")
                                .font(DesignSystem.Typography.bodyMedium)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                            Spacer()
                            Text("\(chaiStrengthRating)/5")
                                .font(DesignSystem.Typography.bodyMedium)
                                .fontWeight(.semibold)
                                .foregroundColor(DesignSystem.Colors.chaiStrengthRating)
                        }
                        
                        HStack(spacing: DesignSystem.Spacing.sm) {
                            ForEach(1..<6) { i in
                                Button(action: { chaiStrengthRating = i }) {
                                    Image(systemName: i <= chaiStrengthRating ? "leaf.fill" : "leaf")
                                        .foregroundColor(strengthColor(for: i))
                                        .font(.system(size: deviceFontSize))
                                        .frame(width: deviceButtonSize, height: deviceButtonSize)
                                        .background(strengthBackground(for: i))
                                        .overlay(strengthOverlay(for: i))
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        
                        HStack {
                            Text("Mild")
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                            Spacer()
                            Text("Strong")
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                    }
                }
                
                Section(header: Text("Chai Type Ordered")) {
                    Button(chaiType.isEmpty ? "Select Chai Type" : chaiType) {
                        showChaiTypeDropdown.toggle()
                    }
                    .padding(.vertical, DesignSystem.Spacing.xs)
                    .padding(.horizontal, DesignSystem.Spacing.sm)
                    .background(DesignSystem.Colors.border)
                    .cornerRadius(DesignSystem.CornerRadius.small)
                    .overlay(chaiTypeButtonOverlay)
                    
                    if showChaiTypeDropdown {
                        chaiTypeDropdownContent
                    }
                }
                
                Section(header: Text("Primary Flavor Notes")) {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        Text("Select the primary flavors you taste:")
                            .font(DesignSystem.Typography.bodyMedium)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        
                        Text("(Optional - tap to select/deselect)")
                            .font(DesignSystem.Typography.caption2)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .italic()
                        
                        LazyVGrid(columns: flavorNotesGridColumns, spacing: DesignSystem.Spacing.sm) {
                            ForEach(allFlavorNotes, id: \.self) { note in
                                flavorNoteButton(for: note)
                            }
                        }
                    }
                }
                
                Section(header: Text("Comment (Optional)")) {
                    TextField("Write something...", text: $comment)
                        .onChange(of: comment) { newValue in
                            validateContentTyping(newValue)
                        }
                    if let warning = inlineWarningMessage {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text(warning)
                                .font(.footnote)
                                .foregroundColor(.orange)
                        }
                    }
                }
                
                Section {
                    Button("Submit Rating") {
                        submitRating()
                    }
                    .disabled(isSubmitting)
                    
                    if isSubmitting {
                        HStack {
                            ProgressView()
                            Text("Submitting...")
                        }
                    }
                }
            }
            .navigationBarTitle("Rate This Spot", displayMode: .inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Content Warning", isPresented: $showContentWarning) {
                Button("Edit Comment", role: .cancel) { }
                Button("Submit Anyway", role: .destructive) {
                    submitRating(forceSubmit: true)
                }
            } message: {
                Text(contentWarningMessage)
            }
        }
        .onAppear {
            if let existing = existingRating {
                ratingValue = existing.value
                comment = existing.comment ?? ""
                creaminessRating = existing.creaminessRating ?? 3
                chaiStrengthRating = existing.chaiStrengthRating ?? 3
                selectedFlavorNotes = Set(existing.flavorNotes ?? [])
                chaiType = existing.chaiType ?? ""
            }
        }
    }
    
    private func validateContentTyping(_ text: String) {
        // Do not trigger warnings for very short inputs to avoid false positives on first keystrokes
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 5 else {
            inlineWarningMessage = nil
            return
        }
        let (isAppropriate, _) = moderationService.filterContent(trimmed)
        inlineWarningMessage = isAppropriate ? nil : "Your comment may contain inappropriate content. Please review and edit if necessary."
    }
    
    func submitRating(forceSubmit: Bool = false) {
        guard let user = Auth.auth().currentUser else {
            return
        }
        
        // Final content validation
        if !forceSubmit && !comment.isEmpty {
            let (isAppropriate, _) = moderationService.filterContent(comment)
            if !isAppropriate {
                contentWarningMessage = "Your comment contains inappropriate content. Please edit it before submitting."
                showContentWarning = true
                return
            }
        }
        
        let userId = user.uid
        isSubmitting = true
        
        // Step 1: Fetch display name from Firestore
        db.collection("users").document(userId).getDocument { document, error in
            var username = user.email ?? user.uid  // Fallback to email or UID
            
            if let doc = document, doc.exists {
                username = doc.get("displayName") as? String ?? username
            }
            
            // Step 2: Build rating dictionary
            var ratingDict: [String: Any] = [
                "spotId": spotId,
                "userId": userId,
                "username": username,
                "value": ratingValue,
                "comment": comment,
                "timestamp": FieldValue.serverTimestamp()
            ]
            
            // Only include likes/dislikes if it's a new rating
            if existingRating == nil {
                ratingDict["likes"] = 0
                ratingDict["dislikes"] = 0
            }
            
            // Add new rating fields
            ratingDict["creaminessRating"] = creaminessRating
            ratingDict["chaiStrengthRating"] = chaiStrengthRating
            ratingDict["flavorNotes"] = Array(selectedFlavorNotes)
            ratingDict["chaiType"] = chaiType.isEmpty ? nil : chaiType
            
            let ratingsCollection = db.collection("ratings")
            
            // Step 3: Save to Firestore
            if let existing = existingRating, let existingId = existing.id {
                ratingsCollection.document(existingId).updateData(ratingDict) { error in
                    DispatchQueue.main.async {
                        self.isSubmitting = false
                        if let error = error {
                            // Handle error silently
                        } else {
                            // Post notification to refresh the feed
                            NotificationCenter.default.post(name: .ratingUpdated, object: nil)
                            self.onComplete()
                        }
                    }
                }
            } else {
                ratingsCollection.addDocument(data: ratingDict) { error in
                    DispatchQueue.main.async {
                        self.isSubmitting = false
                        if let error = error {
                            // Handle error silently
                        } else {
                            // Post notification to refresh the feed
                            NotificationCenter.default.post(name: .ratingUpdated, object: nil)
                            self.onComplete()
                        }
                    }
                }
            }
        }
    }
}
