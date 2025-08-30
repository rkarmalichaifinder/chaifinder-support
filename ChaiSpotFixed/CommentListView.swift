import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore

struct CommentListView: View {
    let spotId: String
    let spotName: String?
    let spotAddress: String?
    
    @State private var comments: [Rating] = []
    @State private var sortByMostHelpful = false
    @State private var showingAddReview = false
    @State private var userExistingRating: Rating?
    @State private var isLoadingUserRating = false
    @State private var isUserAuthenticated = false
    
    @EnvironmentObject var sessionStore: SessionStore
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
        VStack(spacing: 0) {
            // Header with Add Review Button
            headerSection
            
            // Sort Picker
            Picker("Sort", selection: $sortByMostHelpful) {
                Text("Most Recent").tag(false)
                Text("Most Helpful").tag(true)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
            .padding(.bottom, 8)

            // Comments List
            List(sortedComments) { comment in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("\(comment.value)★")
                            .font(DesignSystem.Typography.bodyMedium)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(DesignSystem.Colors.ratingGreen)
                            .cornerRadius(DesignSystem.CornerRadius.small)
                        
                        Spacer()
                        
                        Text(comment.timestamp?.formatted(date: .abbreviated, time: .shortened) ?? "")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }

                    if let text = comment.comment {
                        Text(text)
                            .font(DesignSystem.Typography.bodyMedium)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                    }

                    if let author = comment.username {
                        Text("– \(author)")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }

                    HStack(spacing: 16) {
                        Button {
                            updateVote(commentId: comment.id ?? "", field: "likes")
                        } label: {
                            Label("\(comment.likes ?? 0)", systemImage: "hand.thumbsup")
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }

                        Button {
                            updateVote(commentId: comment.id ?? "", field: "dislikes")
                        } label: {
                            Label("\(comment.dislikes ?? 0)", systemImage: "hand.thumbsdown")
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("All Comments")
        .onAppear {
            checkUserAuthentication()
            loadComments()
            loadUserExistingRating()
        }
        .sheet(isPresented: $showingAddReview) {
            SubmitRatingView(
                spotId: spotId,
                spotName: spotName ?? "Unknown Location",
                spotAddress: spotAddress ?? "Unknown Address",
                existingRating: userExistingRating,
                onComplete: {
                    showingAddReview = false
                    loadComments()
                    loadUserExistingRating()
                }
            )
            .environmentObject(sessionStore)
        }
        .keyboardDismissible()
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            if isUserAuthenticated {
                VStack(spacing: DesignSystem.Spacing.sm) {
                    if isLoadingUserRating {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Loading your review...")
                                .font(DesignSystem.Typography.bodyMedium)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                    } else if let existingRating = userExistingRating {
                        // User has already reviewed this spot
                        VStack(spacing: DesignSystem.Spacing.sm) {
                            HStack {
                                Image(systemName: "star.fill")
                                    .foregroundColor(DesignSystem.Colors.primary)
                                Text("Your Review")
                                    .font(DesignSystem.Typography.headline)
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                            
                            HStack {
                                Text("\(existingRating.value)★")
                                    .font(DesignSystem.Typography.bodyMedium)
                                    .fontWeight(.bold)
                                    .foregroundColor(DesignSystem.Colors.primary)
                                
                                if let comment = existingRating.comment, !comment.isEmpty {
                                    Text("•")
                                        .foregroundColor(DesignSystem.Colors.textSecondary)
                                    Text(comment)
                                        .font(DesignSystem.Typography.bodyMedium)
                                        .foregroundColor(DesignSystem.Colors.textPrimary)
                                        .lineLimit(2)
                                }
                                
                                Spacer()
                            }
                            
                            Button("Edit Your Review") {
                                showingAddReview = true
                            }
                            .font(DesignSystem.Typography.bodyMedium)
                            .fontWeight(.medium)
                            .foregroundColor(DesignSystem.Colors.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DesignSystem.Spacing.sm)
                            .background(DesignSystem.Colors.primary.opacity(0.1))
                            .cornerRadius(DesignSystem.CornerRadius.medium)
                        }
                        .padding(DesignSystem.Spacing.md)
                        .background(DesignSystem.Colors.cardBackground)
                        .cornerRadius(DesignSystem.CornerRadius.medium)
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                                .stroke(DesignSystem.Colors.border.opacity(0.2), lineWidth: 1)
                        )
                    } else {
                        // User hasn't reviewed this spot yet
                        VStack(spacing: DesignSystem.Spacing.sm) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(DesignSystem.Colors.primary)
                                Text("Add Your Review")
                                    .font(DesignSystem.Typography.headline)
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                            
                            Text("Share your experience and help others discover great chai spots!")
                                .font(DesignSystem.Typography.bodyMedium)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                                .multilineTextAlignment(.leading)
                            
                            Button("Write a Review") {
                                showingAddReview = true
                            }
                            .font(DesignSystem.Typography.bodyMedium)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DesignSystem.Spacing.md)
                            .background(DesignSystem.Colors.primary)
                            .cornerRadius(DesignSystem.CornerRadius.medium)
                        }
                        .padding(DesignSystem.Spacing.md)
                        .background(DesignSystem.Colors.cardBackground)
                        .cornerRadius(DesignSystem.CornerRadius.medium)
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                                .stroke(DesignSystem.Colors.border.opacity(0.2), lineWidth: 1)
                        )
                    }
                }
                .padding(.horizontal)
                .padding(.top, DesignSystem.Spacing.md)
            }
        }
    }

    // MARK: - Helper Functions
    private func checkUserAuthentication() {
        isUserAuthenticated = Auth.auth().currentUser != nil
    }
    
    private func loadUserExistingRating() {
        guard let userId = Auth.auth().currentUser?.uid else {
            isLoadingUserRating = false
            return
        }
        
        isLoadingUserRating = true
        
        db.collection("ratings")
            .whereField("spotId", isEqualTo: spotId)
            .whereField("userId", isEqualTo: userId)
            .getDocuments { snapshot, error in
                DispatchQueue.main.async {
                    isLoadingUserRating = false
                    
                    if let error = error {
                        print("❌ Error loading user rating: \(error.localizedDescription)")
                        return
                    }
                    
                    if let document = snapshot?.documents.first {
                        let data = document.data()
                        self.userExistingRating = Rating(
                            id: document.documentID,
                            spotId: data["spotId"] as? String ?? "",
                            userId: data["userId"] as? String ?? "",
                            username: data["username"] as? String ?? data["userName"] as? String,
                            spotName: data["spotName"] as? String,
                            value: data["value"] as? Int ?? 0,
                            comment: data["comment"] as? String,
                            timestamp: (data["timestamp"] as? Timestamp)?.dateValue(),
                            likes: data["likes"] as? Int ?? 0,
                            dislikes: data["dislikes"] as? Int ?? 0,
                            creaminessRating: data["creaminessRating"] as? Int,
                            chaiStrengthRating: data["chaiStrengthRating"] as? Int,
                            flavorNotes: data["flavorNotes"] as? [String]
                        )
                    } else {
                        self.userExistingRating = nil
                    }
                }
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
                        username: data["username"] as? String ?? data["userName"] as? String,
                        spotName: data["spotName"] as? String,
                        value: data["value"] as? Int ?? 0,
                        comment: data["comment"] as? String,
                        timestamp: (data["timestamp"] as? Timestamp)?.dateValue(),
                        likes: data["likes"] as? Int ?? 0,
                        dislikes: data["dislikes"] as? Int ?? 0,
                        creaminessRating: data["creaminessRating"] as? Int,
                        chaiStrengthRating: data["chaiStrengthRating"] as? Int,
                        flavorNotes: data["flavorNotes"] as? [String]
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
                    
                    // 🆕 Trigger feed refresh for comment engagement update
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: .commentEngagementUpdated, object: nil)
                    }
                }
            } else {
                commentRef.updateData([
                    field: FieldValue.increment(Int64(1))
                ])
                voteRef.setData(["type": field])
                loadComments()
                
                // 🆕 Trigger feed refresh for comment engagement update
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .commentEngagementUpdated, object: nil)
                }
            }
        }
    }
}
