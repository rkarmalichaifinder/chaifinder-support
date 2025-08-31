import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseAuth

struct DebugRatingView: View {
    @State private var debugResults: [String] = []
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Debug Rating Data")
                    .font(.title)
                    .padding()
                
                Button("Check Rating Data") {
                    checkRatingData()
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
                
                Button("Fix Invalid Ratings") {
                    fixInvalidRatings()
                }
                .padding()
                .background(Color.red)
                .foregroundColor(.white)
                .cornerRadius(8)
                
                if isLoading {
                    ProgressView("Loading...")
                        .padding()
                }
                
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(debugResults, id: \.self) { result in
                            Text(result)
                                .font(.system(.caption, design: .monospaced))
                                .padding(.horizontal)
                        }
                    }
                }
            }
            .navigationTitle("Debug Ratings")
        }
    }
    
    private func checkRatingData() {
        isLoading = true
        debugResults.removeAll()
        
        let db = Firestore.firestore()
        
        // Get current user ID
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            debugResults.append("❌ No authenticated user")
            isLoading = false
            return
        }
        
        debugResults.append("🔍 Checking ratings for user: \(currentUserId)")
        
        db.collection("ratings")
            .whereField("userId", isEqualTo: currentUserId)
            .order(by: "timestamp", descending: true)
            .limit(to: 10)
            .getDocuments { snapshot, error in
                DispatchQueue.main.async {
                    self.isLoading = false
                    
                    if let error = error {
                        self.debugResults.append("❌ Error: \(error.localizedDescription)")
                        return
                    }
                    
                    guard let documents = snapshot?.documents else {
                        self.debugResults.append("❌ No documents found")
                        return
                    }
                    
                    self.debugResults.append("✅ Found \(documents.count) rating documents")
                    
                    for (index, document) in documents.enumerated() {
                        let data = document.data()
                        self.debugResults.append("--- Document \(index + 1) ---")
                        self.debugResults.append("ID: \(document.documentID)")
                        self.debugResults.append("spotId: \(data["spotId"] ?? "nil")")
                        self.debugResults.append("userId: \(data["userId"] ?? "nil")")
                        self.debugResults.append("rating: \(data["rating"] ?? "nil") (type: \(type(of: data["rating"] ?? "nil")))")
                        self.debugResults.append("spotName: \(data["spotName"] ?? "nil")")
                        self.debugResults.append("Available fields: \(Array(data.keys))")
                        
                        // Check rating value specifically
                        if let ratingValue = data["rating"] {
                            if let intValue = ratingValue as? Int {
                                self.debugResults.append("✅ Rating as Int: \(intValue)")
                            } else if let doubleValue = ratingValue as? Double {
                                self.debugResults.append("⚠️ Rating as Double: \(doubleValue)")
                            } else {
                                self.debugResults.append("❌ Rating as other type: \(ratingValue)")
                            }
                        } else {
                            self.debugResults.append("❌ Rating field is missing!")
                        }
                    }
                    
                    // Also check a few random ratings from other users
                    self.checkRandomRatings()
                }
            }
    }
    
    private func checkRandomRatings() {
        let db = Firestore.firestore()
        
        debugResults.append("--- Checking Random Ratings ---")
        
        db.collection("ratings")
            .order(by: "timestamp", descending: true)
            .limit(to: 5)
            .getDocuments { snapshot, error in
                DispatchQueue.main.async {
                    if let error = error {
                        self.debugResults.append("❌ Error checking random ratings: \(error.localizedDescription)")
                        return
                    }
                    
                    guard let documents = snapshot?.documents else {
                        self.debugResults.append("❌ No random rating documents found")
                        return
                    }
                    
                    self.debugResults.append("✅ Found \(documents.count) random rating documents")
                    
                    for (index, document) in documents.enumerated() {
                        let data = document.data()
                        self.debugResults.append("Random Doc \(index + 1):")
                        self.debugResults.append("  rating: \(data["rating"] ?? "nil") (type: \(type(of: data["rating"] ?? "nil")))")
                        self.debugResults.append("  userId: \(data["userId"] ?? "nil")")
                    }
                }
            }
    }
    
    private func fixInvalidRatings() {
        isLoading = true
        debugResults.removeAll()
        debugResults.append("🔧 Starting to fix invalid ratings...")
        
        let db = Firestore.firestore()
        var lastDoc: DocumentSnapshot?
        var totalProcessed = 0
        var totalFixed = 0
        
        func processBatch() {
            var query: Query = db.collection("ratings")
                .order(by: FieldPath.documentID())
                .limit(to: 100)
            
            if let last = lastDoc {
                query = query.start(afterDocument: last)
            }
            
            query.getDocuments { snapshot, error in
                DispatchQueue.main.async {
                    if let error = error {
                        self.debugResults.append("❌ Error processing batch: \(error.localizedDescription)")
                        self.isLoading = false
                        return
                    }
                    
                    guard let snapshot = snapshot, !snapshot.documents.isEmpty else {
                        self.debugResults.append("✅ Fix completed! Total processed: \(totalProcessed), Total fixed: \(totalFixed)")
                        self.isLoading = false
                        return
                    }
                    
                    let batch = db.batch()
                    var batchFixed = 0
                    
                    for doc in snapshot.documents {
                        let data = doc.data()
                        var needsUpdate = false
                        var patch: [String: Any] = [:]
                        
                        // Check for invalid rating values
                        if let ratingValue = data["rating"] {
                            if let intValue = ratingValue as? Int {
                                if intValue < 1 || intValue > 5 {
                                    self.debugResults.append("🔧 Fixing invalid rating value: \(intValue) -> 3")
                                    patch["rating"] = 3
                                    needsUpdate = true
                                }
                            } else if let doubleValue = ratingValue as? Double {
                                let intValue = Int(doubleValue)
                                if intValue < 1 || intValue > 5 {
                                    self.debugResults.append("🔧 Fixing invalid rating value: \(doubleValue) -> 3")
                                    patch["rating"] = 3
                                    needsUpdate = true
                                } else if doubleValue != Double(intValue) {
                                    self.debugResults.append("🔧 Converting Double to Int: \(doubleValue) -> \(intValue)")
                                    patch["rating"] = intValue
                                    needsUpdate = true
                                }
                            } else if let stringValue = ratingValue as? String, let intValue = Int(stringValue) {
                                if intValue < 1 || intValue > 5 {
                                    self.debugResults.append("🔧 Fixing invalid rating value: \(stringValue) -> 3")
                                    patch["rating"] = 3
                                    needsUpdate = true
                                } else {
                                    self.debugResults.append("🔧 Converting String to Int: \(stringValue) -> \(intValue)")
                                    patch["rating"] = intValue
                                    needsUpdate = true
                                }
                            } else {
                                self.debugResults.append("🔧 Setting missing/invalid rating to default: 3")
                                patch["rating"] = 3
                                needsUpdate = true
                            }
                        } else {
                            self.debugResults.append("🔧 Adding missing rating field with default: 3")
                            patch["rating"] = 3
                            needsUpdate = true
                        }
                        
                        if needsUpdate {
                            batch.updateData(patch, forDocument: doc.reference)
                            batchFixed += 1
                        }
                    }
                    
                    if batchFixed > 0 {
                        batch.commit { batchError in
                            DispatchQueue.main.async {
                                if let batchError = batchError {
                                    self.debugResults.append("❌ Batch commit error: \(batchError.localizedDescription)")
                                    self.isLoading = false
                                    return
                                }
                                
                                totalProcessed += snapshot.documents.count
                                totalFixed += batchFixed
                                self.debugResults.append("🔄 Processed batch: \(snapshot.documents.count) docs, fixed: \(batchFixed). Total: \(totalProcessed)/\(totalFixed)")
                                
                                lastDoc = snapshot.documents.last
                                processBatch()
                            }
                        }
                    } else {
                        totalProcessed += snapshot.documents.count
                        lastDoc = snapshot.documents.last
                        processBatch()
                    }
                }
            }
        }
        
        processBatch()
    }
}
