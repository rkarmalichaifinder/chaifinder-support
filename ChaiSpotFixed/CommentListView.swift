import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore

struct CommentListView: View {
    let spotId: String
    @State private var comments: [Rating] = []
    @State private var sortByMostHelpful = false
    let db = Firestore.firestore()

    var sortedComments: [Rating] {
        if sortByMostHelpful {
            return comments.sorted {
                ($0.likes ?? 0) - ($0.dislikes ?? 0) > ($1.likes ?? 0) - ($1.dislikes ?? 0)
            }
        } else {
            return comments.sorted {
                ($0.timestamp ?? Date.distantPast) > ($1.timestamp ?? Date.distantPast)
            }
        }
    }

    var body: some View {
        VStack {
            Picker("Sort", selection: $sortByMostHelpful) {
                Text("Most Recent").tag(false)
                Text("Most Helpful").tag(true)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()

            List(sortedComments) { comment in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("⭐️ \(comment.value)")
                        Spacer()
                        Text(comment.timestamp?.formatted(date: .abbreviated, time: .shortened) ?? "")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }

                    if let text = comment.comment {
                        Text(text)
                            .font(.body)
                    }

                    if let author = comment.username {
                        Text("– \(author)")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }


                    HStack(spacing: 16) {
                        Button {
                            updateVote(commentId: comment.id ?? "", field: "likes")
                        } label: {
                            Label("\(comment.likes ?? 0)", systemImage: "hand.thumbsup")
                        }

                        Button {
                            updateVote(commentId: comment.id ?? "", field: "dislikes")
                        } label: {
                            Label("\(comment.dislikes ?? 0)", systemImage: "hand.thumbsdown")
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.gray)
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("All Comments")
        .onAppear {
            loadComments()
        }
    }

    private func loadComments() {
        db.collection("ratings")
            .whereField("spotId", isEqualTo: spotId)
            .order(by: "timestamp", descending: true)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ Error loading comments: \(error.localizedDescription)")
                    return
                }
                
                self.comments = snapshot?.documents.compactMap { doc -> Rating? in
                    let data = doc.data()
                    return Rating(
                        id: doc.documentID,
                        spotId: data["spotId"] as? String ?? "",
                        userId: data["userId"] as? String ?? "",
                        username: data["username"] as? String,
                        spotName: data["spotName"] as? String,
                        value: data["value"] as? Int ?? 0,
                        comment: data["comment"] as? String,
                        timestamp: (data["timestamp"] as? Timestamp)?.dateValue(),
                        likes: data["likes"] as? Int ?? 0,
                        dislikes: data["dislikes"] as? Int ?? 0
                    )
                } ?? []
                
                print("✅ Loaded \(self.comments.count) comments for spot \(self.spotId)")
            }
    }

    private func updateVote(commentId: String, field: String) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        let commentRef = db.collection("ratings").document(commentId)
        let voteRef = commentRef.collection("votes").document(userId)

        voteRef.getDocument { snapshot, error in
            if let data = snapshot?.data(), let existing = data["type"] as? String {
                if existing == field {
                    return // already voted this way
                } else {
                    commentRef.updateData([
                        existing: FieldValue.increment(Int64(-1)),
                        field: FieldValue.increment(Int64(1))
                    ])
                    voteRef.setData(["type": field])
                    loadComments()
                }
            } else {
                commentRef.updateData([
                    field: FieldValue.increment(Int64(1))
                ])
                voteRef.setData(["type": field])
                loadComments()
            }
        }
    }
}
