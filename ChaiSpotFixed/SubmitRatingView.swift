import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct SubmitRatingView: View {
    let spotId: String
    let existingRating: Rating?
    let onComplete: () -> Void
    
    @State private var ratingValue: Int = 3
    @State private var comment: String = ""
    @State private var isSubmitting = false
    
    private let db = Firestore.firestore()
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Your Rating")) {
                    Stepper("Rating: \(ratingValue) Stars", value: $ratingValue, in: 1...5)
                }
                
                Section(header: Text("Comment (Optional)")) {
                    TextField("Write something...", text: $comment)
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
        }
        .onAppear {
            if let existing = existingRating {
                ratingValue = existing.value
                comment = existing.comment ?? ""
            }
        }
    }
    
    func submitRating() {
        guard let user = Auth.auth().currentUser else {
            print("❌ User not logged in")
            return
        }
        
        let userId = user.uid
        isSubmitting = true
        print("📝 Submitting comment: \(comment)")
        
        // Step 1: Fetch display name from Firestore
        db.collection("users").document(userId).getDocument { document, error in
            var username = user.email ?? user.uid  // Fallback name
            if let doc = document, doc.exists {
                username = doc.get("displayName") as? String ?? username
            }
            
            // Step 2: Build rating dictionary
            let ratingDict: [String: Any] = [
                "spotId": spotId,
                "userId": userId,
                "username": username,
                "value": ratingValue,
                "comment": comment,
                "timestamp": FieldValue.serverTimestamp()
            ]
            
            let ratingsCollection = db.collection("ratings")
            
            // Step 3: Save to Firestore
            if let existing = existingRating, let existingId = existing.id {
                ratingsCollection.document(existingId).updateData(ratingDict) { error in
                    DispatchQueue.main.async {
                        self.isSubmitting = false
                        if let error = error {
                            print("❌ Error updating rating: \(error.localizedDescription)")
                        } else {
                            print("✅ Rating updated successfully!")
                            self.onComplete()
                        }
                    }
                }
            } else {
                ratingsCollection.addDocument(data: ratingDict) { error in
                    DispatchQueue.main.async {
                        self.isSubmitting = false
                        if let error = error {
                            print("❌ Firestore error: \(error.localizedDescription)")
                        } else {
                            print("✅ Rating saved successfully!")
                            self.onComplete()
                        }
                    }
                }
            }
        }
    }
}
