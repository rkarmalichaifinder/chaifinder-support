import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore

struct SubmitRatingView: View {
    let spotId: String
    let existingRating: Rating?
    let onComplete: () -> Void
    
    @State private var ratingValue: Int = 3
    @State private var comment: String = ""
    @State private var isSubmitting = false
    @State private var showContentWarning = false
    @State private var contentWarningMessage = ""
    @State private var inlineWarningMessage: String? = nil
    @StateObject private var moderationService = ContentModerationService()
    
    private let db = Firestore.firestore()
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Your Rating")) {
                    Stepper("Rating: \(ratingValue) Stars", value: $ratingValue, in: 1...5)
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
                        onComplete()
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
            
            let ratingsCollection = db.collection("ratings")
            
            // Step 3: Save to Firestore
            if let existing = existingRating, let existingId = existing.id {
                ratingsCollection.document(existingId).updateData(ratingDict) { error in
                    DispatchQueue.main.async {
                        self.isSubmitting = false
                        if let error = error {
                            // Handle error silently
                        } else {
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
                            self.onComplete()
                        }
                    }
                }
            }
        }
    }
}
