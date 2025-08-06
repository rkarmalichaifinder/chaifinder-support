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
            return
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
