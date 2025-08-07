import SwiftUI
import MapKit
import FirebaseAuth
import FirebaseFirestore

struct ChaiSpotDetailSheet: View {
    let spot: ChaiSpot
    let userLocation: CLLocation?
    @Environment(\.dismiss) private var dismiss
    @State private var ratings: [Rating] = []
    @State private var friendRatings: [Rating] = []
    @State private var isLoadingRatings = false
    @State private var isLoadingFriendRatings = false
    @State private var showingRatingSheet = false
    @State private var isAddingToList = false
    @State private var showingAddToListAlert = false
    @State private var addToListMessage = ""
    @State private var showingFriendRatings = false
    
    var distanceString: String {
        guard let userLocation = userLocation else {
            return "Distance unknown"
        }
        
        let spotLocation = CLLocation(latitude: spot.latitude, longitude: spot.longitude)
        let distance = userLocation.distance(from: spotLocation)
        
        if distance < 1000 {
            return "\(Int(distance))m away"
        } else {
            return String(format: "%.1f miles away", distance / 1609.34)
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                    // Header
                    headerSection
                    
                    // Rating Section
                    if isLoadingRatings {
                        loadingSection
                    } else {
                        ratingSection
                    }
                    
                    // Chai Types Section
                    if !spot.chaiTypes.isEmpty {
                        chaiTypesSection
                    }
                    
                    // Action Buttons
                    actionButtonsSection
                }
                .padding(DesignSystem.Spacing.lg)
            }
            .background(DesignSystem.Colors.background)
            .navigationTitle("Spot Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(DesignSystem.Colors.primary)
                }
            }
        }
        .onAppear {
            loadRatings()
            loadFriendRatings()
        }
        .sheet(isPresented: $showingRatingSheet) {
            SubmitRatingView(
                spotId: spot.id,
                existingRating: nil,
                onComplete: {
                    showingRatingSheet = false
                    loadRatings() // Refresh ratings after submission
                }
            )
        }
        .alert("Add to List", isPresented: $showingAddToListAlert) {
            Button("OK") { }
        } message: {
            Text(addToListMessage)
        }
    }
    
    // MARK: - View Components
    
    private var loadingSection: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading ratings...")
                .font(DesignSystem.Typography.bodyMedium)
                .foregroundColor(DesignSystem.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(DesignSystem.Spacing.xl)
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text(spot.name)
                .font(DesignSystem.Typography.titleLarge)
                .fontWeight(.bold)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            
            HStack {
                Image(systemName: "location.fill")
                    .foregroundColor(DesignSystem.Colors.primary)
                    .font(.caption)
                
                Text(spot.address)
                    .font(DesignSystem.Typography.bodyLarge)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
            
            HStack {
                Image(systemName: "location.circle.fill")
                    .foregroundColor(DesignSystem.Colors.secondary)
                    .font(.caption)
                
                Text(distanceString)
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.medium)
    }
    
    private var ratingSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                Text("Rating")
                    .font(DesignSystem.Typography.headline)
                    .fontWeight(.bold)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                
                Spacer()
                
                // Friend Ratings Toggle
                if !friendRatings.isEmpty {
                    Button(action: {
                        showingFriendRatings.toggle()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: showingFriendRatings ? "person.2.fill" : "person.2")
                                .font(.system(size: 14))
                            Text(showingFriendRatings ? "Friends" : "All")
                                .font(DesignSystem.Typography.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(showingFriendRatings ? DesignSystem.Colors.primary : DesignSystem.Colors.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(showingFriendRatings ? DesignSystem.Colors.primary.opacity(0.1) : Color.clear)
                        )
                    }
                }
            }
            
            if isLoadingRatings {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading ratings...")
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            } else if (showingFriendRatings ? friendRatings : ratings).isEmpty {
                Text(showingFriendRatings ? "No friend ratings yet" : "No ratings yet")
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            } else {
                averageRatingView
                individualRatingsView
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.medium)
    }
    
    private var averageRatingView: some View {
        HStack {
            let currentRatings = showingFriendRatings ? friendRatings : ratings
            let average = currentRatings.isEmpty ? 0.0 : Double(currentRatings.reduce(0) { $0 + $1.value }) / Double(currentRatings.count)
            
            Text("\(String(format: "%.1f", average))★")
                .font(DesignSystem.Typography.titleMedium)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.vertical, DesignSystem.Spacing.sm)
                .background(DesignSystem.Colors.ratingGreen)
                .cornerRadius(DesignSystem.CornerRadius.medium)
            
            Text("\(currentRatings.count) \(showingFriendRatings ? "friend" : "") reviews")
                .font(DesignSystem.Typography.bodyLarge)
                .foregroundColor(DesignSystem.Colors.textSecondary)
            
            Spacer()
        }
    }
    
    private var individualRatingsView: some View {
        LazyVStack(spacing: DesignSystem.Spacing.md) {
            if showingFriendRatings {
                ForEach(friendRatings) { rating in
                    ratingCard(rating)
                }
            } else {
                ForEach(ratings.prefix(5)) { rating in
                    ratingCard(rating)
                }
            }
        }
    }
    
    private func ratingCard(_ rating: Rating) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            HStack {
                Text(rating.username ?? "Anonymous")
                    .font(DesignSystem.Typography.bodyMedium)
                    .fontWeight(.medium)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                
                Spacer()
                
                Text("\(rating.value)★")
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(DesignSystem.Colors.primary)
            }
            
            if let comment = rating.comment, !comment.isEmpty {
                Text(comment)
                    .font(DesignSystem.Typography.bodySmall)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
            
            if let timestamp = rating.timestamp {
                Text(timestamp, style: .relative)
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.secondary.opacity(0.05))
        .cornerRadius(DesignSystem.CornerRadius.small)
    }
    
    private var chaiTypesSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Available Chai Types")
                .font(DesignSystem.Typography.headline)
                .fontWeight(.bold)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: DesignSystem.Spacing.sm) {
                ForEach(spot.chaiTypes, id: \.self) { chaiType in
                    Text(chaiType)
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .padding(DesignSystem.Spacing.sm)
                        .background(DesignSystem.Colors.secondary.opacity(0.1))
                        .cornerRadius(DesignSystem.CornerRadius.small)
                }
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.medium)
    }
    
    private var actionButtonsSection: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Button("Rate This Spot") {
                showingRatingSheet = true
            }
            .buttonStyle(PrimaryButtonStyle())
            
            Button(isAddingToList ? "Adding to List..." : "Add to My List") {
                addToMyList()
            }
            .buttonStyle(SecondaryButtonStyle())
            .disabled(isAddingToList)
            
            Button("Get Directions") {
                // Open in Maps
                let coordinate = spot.coordinate
                let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
                mapItem.name = spot.name
                mapItem.openInMaps(launchOptions: nil)
            }
            .buttonStyle(SecondaryButtonStyle())
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.medium)
    }
    
    private func addToMyList() {
        guard let userId = Auth.auth().currentUser?.uid else {
            addToListMessage = "Please log in to save spots to your list"
            showingAddToListAlert = true
            return
        }
        
        isAddingToList = true
        let db = Firestore.firestore()
        
        // First check if the user document exists and has savedSpots field
        db.collection("users").document(userId).getDocument { snapshot, error in
            if let error = error {
                DispatchQueue.main.async {
                    self.isAddingToList = false
                    self.addToListMessage = "Failed to add to list: \(error.localizedDescription)"
                    self.showingAddToListAlert = true
                }
                return
            }
            
            if let data = snapshot?.data(), let existingSavedSpots = data["savedSpots"] as? [String] {
                // User document exists and has savedSpots field
                self.updateSavedSpots(userId: userId, spotId: self.spot.id, existingSpots: existingSavedSpots)
            } else {
                // User document exists but no savedSpots field, or document doesn't exist
                self.createSavedSpotsField(userId: userId, spotId: self.spot.id)
            }
        }
    }
    
    private func updateSavedSpots(userId: String, spotId: String, existingSpots: [String]) {
        let db = Firestore.firestore()
        
        // Check if spot is already saved
        if existingSpots.contains(spotId) {
            DispatchQueue.main.async {
                self.isAddingToList = false
                self.addToListMessage = "✅ \(self.spot.name) is already in your list!"
                self.showingAddToListAlert = true
            }
            return
        }
        
        // Add to existing saved spots
        var updatedSpots = existingSpots
        updatedSpots.append(spotId)
        
        db.collection("users").document(userId).updateData([
            "savedSpots": updatedSpots
        ]) { error in
            DispatchQueue.main.async {
                self.isAddingToList = false
                
                if let error = error {
                    self.addToListMessage = "Failed to add to list: \(error.localizedDescription)"
                    self.showingAddToListAlert = true
                } else {
                    self.addToListMessage = "✅ \(self.spot.name) added to your list!"
                    self.showingAddToListAlert = true
                }
            }
        }
    }
    
    private func createSavedSpotsField(userId: String, spotId: String) {
        let db = Firestore.firestore()
        
        db.collection("users").document(userId).setData([
            "savedSpots": [spotId]
        ], merge: true) { error in
            DispatchQueue.main.async {
                self.isAddingToList = false
                
                if let error = error {
                    self.addToListMessage = "Failed to add to list: \(error.localizedDescription)"
                    self.showingAddToListAlert = true
                } else {
                    self.addToListMessage = "✅ \(self.spot.name) added to your list!"
                    self.showingAddToListAlert = true
                }
            }
        }
    }
    
    private func loadRatings() {
        isLoadingRatings = true
        let db = Firestore.firestore()
        
        db.collection("ratings")
            .whereField("spotId", isEqualTo: spot.id)
            .order(by: "timestamp", descending: true)
            .limit(to: 10)
            .getDocuments { snapshot, error in
                DispatchQueue.main.async {
                    self.isLoadingRatings = false
                    
                    if let error = error {
                        return
                    }
                    
                    guard let documents = snapshot?.documents else {
                        return
                    }
                    
                    self.ratings = documents.compactMap { document -> Rating? in
                        guard let data = document.data() as? [String: Any],
                              let spotId = data["spotId"] as? String,
                              let userId = data["userId"] as? String,
                              let value = data["value"] as? Int else {
                            if let data = document.data() as? [String: Any] {
                            }
                            return nil
                        }
                        
                        let username = data["username"] as? String
                        let comment = data["comment"] as? String
                        let timestamp = data["timestamp"] as? Timestamp
                        let likes = data["likes"] as? Int
                        let dislikes = data["dislikes"] as? Int
                        
                        return Rating(
                            spotId: spotId,
                            userId: userId,
                            username: username,
                            value: value,
                            comment: comment,
                            timestamp: timestamp?.dateValue(),
                            likes: likes,
                            dislikes: dislikes
                        )
                    }
                }
            }
    }
    
    private func loadFriendRatings() {
        isLoadingFriendRatings = true
        
        FriendService.getFriendsRatings(forSpotId: spot.id) { ratings in
            DispatchQueue.main.async {
                self.isLoadingFriendRatings = false
                self.friendRatings = ratings
            }
        }
    }
} 
