import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore

struct SavedSpotsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var savedSpots: [ChaiSpot] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.Colors.background
                    .ignoresSafeArea()
                
                if isLoading {
                    VStack {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Loading your saved spots...")
                            .font(DesignSystem.Typography.bodyLarge)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .padding(.top, DesignSystem.Spacing.md)
                    }
                } else if let errorMessage = errorMessage {
                    VStack(spacing: DesignSystem.Spacing.lg) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundColor(DesignSystem.Colors.secondary)
                        
                        Text("Error")
                            .font(DesignSystem.Typography.headline)
                            .fontWeight(.bold)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        
                        Text(errorMessage)
                            .font(DesignSystem.Typography.bodyMedium)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                        
                        Button("Try Again") {
                            loadSavedSpots()
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                    .padding(DesignSystem.Spacing.xl)
                } else if savedSpots.isEmpty {
                    VStack(spacing: DesignSystem.Spacing.lg) {
                        Image(systemName: "heart")
                            .font(.system(size: 48))
                            .foregroundColor(DesignSystem.Colors.secondary)
                        
                        Text("No Saved Spots")
                            .font(DesignSystem.Typography.headline)
                            .fontWeight(.bold)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        
                        Text("Spots you save will appear here")
                            .font(DesignSystem.Typography.bodyMedium)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(DesignSystem.Spacing.xl)
                } else {
                    ScrollView {
                        LazyVStack(spacing: DesignSystem.Spacing.md) {
                            ForEach(savedSpots) { spot in
                                SavedSpotCard(spot: spot) {
                                    // Remove from list callback
                                    if let index = savedSpots.firstIndex(where: { $0.id == spot.id }) {
                                        savedSpots.remove(at: index)
                                    }
                                }
                            }
                        }
                        .padding(DesignSystem.Spacing.lg)
                    }
                }
            }
            .navigationTitle("My List")
            .navigationBarTitleDisplayMode(.large)
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
            loadSavedSpots()
        }
    }
    
    private func loadSavedSpots() {
        guard let userId = Auth.auth().currentUser?.uid else {
            errorMessage = "Please log in to view your saved spots"
            isLoading = false
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        let db = Firestore.firestore()
        
        // First, get the user's saved spots IDs
        db.collection("users").document(userId).getDocument { snapshot, error in
            if let error = error {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to load saved spots: \(error.localizedDescription)"
                    self.isLoading = false
                }
                return
            }
            
            guard let data = snapshot?.data() else {
                DispatchQueue.main.async {
                    self.errorMessage = "No user data found"
                    self.isLoading = false
                }
                return
            }
            
            guard let savedSpotIds = data["savedSpots"] as? [String] else {
                DispatchQueue.main.async {
                    self.savedSpots = []
                    self.isLoading = false
                }
                return
            }
            
            if savedSpotIds.isEmpty {
                DispatchQueue.main.async {
                    self.savedSpots = []
                    self.isLoading = false
                }
                return
            }
            
            // Now load the full ChaiSpot data for each saved spot
            loadChaiSpotsData(savedSpotIds: savedSpotIds)
        }
    }
    
    private func loadChaiSpotsData(savedSpotIds: [String]) {
        let db = Firestore.firestore()
        let group = DispatchGroup()
        var loadedSpots: [ChaiSpot] = []
        var loadError: String?
        
        for spotId in savedSpotIds {
            group.enter()
            
            db.collection("chaiFinder").document(spotId).getDocument { snapshot, error in
                defer { group.leave() }
                
                if let error = error {
                    loadError = "Failed to load spot data: \(error.localizedDescription)"
                    return
                }
                
                guard let data = snapshot?.data(),
                      let name = data["name"] as? String,
                      let latitude = data["latitude"] as? Double,
                      let longitude = data["longitude"] as? Double,
                      let address = data["address"] as? String else {
                    return
                }
                
                let chaiTypes = data["chaiTypes"] as? [String] ?? []
                let averageRating = data["averageRating"] as? Double ?? 0.0
                let ratingCount = data["ratingCount"] as? Int ?? 0
                
                let spot = ChaiSpot(
                    id: spotId,
                    name: name,
                    address: address,
                    latitude: latitude,
                    longitude: longitude,
                    chaiTypes: chaiTypes,
                    averageRating: averageRating,
                    ratingCount: ratingCount
                )
                
                loadedSpots.append(spot)
            }
        }
        
        group.notify(queue: .main) {
            if let error = loadError {
                self.errorMessage = error
            } else {
                self.savedSpots = loadedSpots
            }
            self.isLoading = false
        }
    }
}

// MARK: - Saved Spot Card
struct SavedSpotCard: View {
    let spot: ChaiSpot
    let onRemove: () -> Void
    @State private var showingRemoveAlert = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text(spot.name)
                        .font(DesignSystem.Typography.headline)
                        .fontWeight(.bold)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    
                    Text(spot.address)
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                
                Spacer()
                
                // Heart Icon
                Image(systemName: "heart.fill")
                    .foregroundColor(DesignSystem.Colors.primary)
                    .font(.title2)
            }
            
            // Chai Types
            if !spot.chaiTypes.isEmpty {
                Text("Chai Types: \(spot.chaiTypes.joined(separator: ", "))")
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
            
            // Rating
            if spot.averageRating > 0 {
                HStack {
                    Text("\(String(format: "%.1f", spot.averageRating))★")
                        .font(DesignSystem.Typography.bodyMedium)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, DesignSystem.Spacing.sm)
                        .padding(.vertical, DesignSystem.Spacing.xs)
                        .background(DesignSystem.Colors.ratingGreen)
                        .cornerRadius(DesignSystem.CornerRadius.small)
                    
                    Text("\(spot.ratingCount) reviews")
                        .font(DesignSystem.Typography.bodySmall)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    
                    Spacer()
                    
                    // Remove Button
                    Button("Remove") {
                        showingRemoveAlert = true
                    }
                    .font(DesignSystem.Typography.bodySmall)
                    .foregroundColor(DesignSystem.Colors.secondary)
                }
            } else {
                HStack {
                    Text("No ratings yet")
                        .font(DesignSystem.Typography.bodySmall)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    
                    Spacer()
                    
                    // Remove Button
                    Button("Remove") {
                        showingRemoveAlert = true
                    }
                    .font(DesignSystem.Typography.bodySmall)
                    .foregroundColor(DesignSystem.Colors.secondary)
                }
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.medium)
        .shadow(
            color: DesignSystem.Shadows.small.color,
            radius: DesignSystem.Shadows.small.radius,
            x: DesignSystem.Shadows.small.x,
            y: DesignSystem.Shadows.small.y
        )
        .alert("Remove from List", isPresented: $showingRemoveAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Remove", role: .destructive) {
                removeFromList()
            }
        } message: {
            Text("Are you sure you want to remove \(spot.name) from your saved spots?")
        }
    }
    
    private func removeFromList() {
        guard let userId = Auth.auth().currentUser?.uid else {
            return
        }
        
        let db = Firestore.firestore()
        
        db.collection("users").document(userId).updateData([
            "savedSpots": FieldValue.arrayRemove([spot.id])
        ]) { error in
            if let error = error {
                // Handle error silently
            } else {
                onRemove()
            }
        }
    }
} 