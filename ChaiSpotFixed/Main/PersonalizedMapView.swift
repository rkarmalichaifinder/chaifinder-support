import SwiftUI
import CoreLocation
import MapKit
import FirebaseFirestore
import FirebaseAuth

struct PersonalizedMapView: View {
    @EnvironmentObject var session: SessionStore
    @StateObject private var vm = PersonalizedMapViewModel()
    @State private var showingHelp = false
    @State private var showingFilters = false
    @State private var showingAddSpot = false
    @State private var selectedSpot: ChaiSpot? = nil

    var body: some View {
        NavigationView {
            ZStack {
                if vm.isLoading {
                    loadingView
                } else if vm.hasError {
                    errorView
                } else if vm.allSpots.isEmpty {
                    emptyStateView
                } else {
                    mapContentView
                }
            }
            .onAppear {
                print("🎯 PersonalizedMapView appeared")
                print("🎯 ViewModel state - isLoading: \(vm.isLoading), hasError: \(vm.hasError), spots: \(vm.allSpots.count), mapView: \(vm.mapView != nil)")
                
                // Set up spot selection handler
                vm.setSpotSelectionHandler { spot in
                    self.selectedSpot = spot
                }
            }
            .onChange(of: vm.isShowingList) { newValue in
                print("🎯 ViewModel isShowingList changed to: \(newValue)")
            }
                    .navigationTitle("My Chai Map")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { showingHelp = true }) {
                    Image(systemName: "questionmark.circle")
                        .foregroundColor(.secondary)
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    // Simple toggle buttons instead of segmented control
                    HStack(spacing: 0) {
                        Button(action: {
                            vm.isShowingList = false
                            print("🔧 Map button pressed - isShowingList: \(vm.isShowingList)")
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "map")
                                Text("Map")
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(vm.isShowingList ? Color.clear : DesignSystem.Colors.primary)
                            .foregroundColor(vm.isShowingList ? DesignSystem.Colors.textSecondary : .white)
                            .cornerRadius(8)
                        }
                        
                        Button(action: {
                            vm.isShowingList = true
                            print("🔧 List button pressed - isShowingList: \(vm.isShowingList)")
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "list.bullet")
                                Text("List")
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(vm.isShowingList ? DesignSystem.Colors.primary : Color.clear)
                            .foregroundColor(vm.isShowingList ? .white : DesignSystem.Colors.textSecondary)
                            .cornerRadius(8)
                        }
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(DesignSystem.Colors.border, lineWidth: 1)
                    )
                    
                    Button(action: { showingAddSpot = true }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(DesignSystem.Colors.primary)
                            .font(.title2)
                    }
                    
                    Button(action: { showingFilters = true }) {
                        Image(systemName: "slider.horizontal.3")
                            .foregroundColor(.secondary)
                    }
                    .disabled(vm.allSpots.isEmpty)
                }
            }
        }
        }
        .task {
            print("🚀 PersonalizedMapView task started")
            print("🚀 Current user ID: \(session.currentUser?.uid ?? "nil")")
            await vm.load(for: session.currentUser?.uid)
            print("🚀 PersonalizedMapView task completed")
        }
        .refreshable {
            await vm.load(for: session.currentUser?.uid)
        }
        .sheet(isPresented: $showingHelp) {
            MapHelpView()
        }
        .sheet(isPresented: $showingFilters) {
            MapFiltersView(viewModel: vm)
        }
        .sheet(isPresented: $showingAddSpot) {
            AddChaiFinderForm(
                coordinate: nil,
                onSubmit: { name, address, rating, comments, types, coordinate, creaminess, strength, flavorNotes in
                    // TODO: Save the new chai spot
                    print("Adding new chai spot: \(name) at \(coordinate)")
                    showingAddSpot = false
                }
            )
        }
        .sheet(item: $selectedSpot) { spot in
            SpotDetailSheet(spot: spot)
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.2)
            
            VStack(spacing: 8) {
                Text("Loading your personalized map...")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("We're finding the best chai spots for you")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var errorView: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            VStack(spacing: 8) {
                Text("Something went wrong")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(vm.errorMessage ?? "Unable to load your personalized map")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button("Try Again") {
                Task {
                    await vm.load(for: session.currentUser?.uid)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "map")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            VStack(spacing: 12) {
                Text("No chai spots found")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("There are no chai spots in the database yet. Be the first to add one!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            VStack(spacing: 12) {
                Button("Add Chai Spot") {
                    showingAddSpot = true
                }
                .buttonStyle(.borderedProminent)
                
                Button("Refresh") {
                    Task {
                        await vm.load(for: session.currentUser?.uid)
                    }
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var mapContentView: some View {
        VStack(spacing: 0) {
            if vm.isShowingList {
                // List view of all spots
                listView
                    .onAppear {
                        print("📋 List view appeared with \(vm.allSpots.count) spots")
                    }
                            } else {
                    // Full-screen map view
                    if vm.isLoading {
                        VStack {
                            Text("Loading map...")
                                .font(.headline)
                            ProgressView()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if vm.hasError {
                        VStack {
                            Text("Map Error")
                                .font(.headline)
                            Text(vm.errorMessage ?? "Unknown error")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            Button("Retry") {
                                Task {
                                    await vm.load(for: session.currentUser?.uid)
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if vm.mapView != nil {
                        fullScreenMapView
                    } else {
                        VStack {
                            Text("No map data")
                                .font(.headline)
                            Text("Unable to load map view")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            
            // Bottom info panel (always visible)
            if let reason = vm.reasonText {
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.secondary)
                        Text(reason)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        Spacer()
                        
                        Text("\(vm.personalizedSpots.count) personalized")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    Divider()
                }
                .background(.ultraThinMaterial)
            }
        }
    }
    
    private var fullScreenMapView: some View {
        Group {
            if let mapView = vm.mapView {
                mapView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .onAppear {
                        print("🗺️ Map view appeared")
                    }
                    .overlay(
                        // Map controls overlay
                        VStack {
                            HStack {
                                Spacer()
                                
                                VStack(spacing: 8) {
                                    Button(action: { vm.centerOnUser() }) {
                                        Image(systemName: "location")
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(.primary)
                                            .frame(width: 40, height: 40)
                                            .background(.ultraThinMaterial)
                                            .clipShape(Circle())
                                    }
                                    
                                    Button(action: { vm.zoomToFit() }) {
                                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(.primary)
                                            .frame(width: 40, height: 40)
                                            .background(.ultraThinMaterial)
                                            .clipShape(Circle())
                                    }
                                }
                            }
                            .padding()
                            
                            Spacer()
                            
                            // Map legend
                            if !vm.personalizedSpots.isEmpty {
                                HStack {
                                    Spacer()
                                    
                                    VStack(spacing: 4) {
                                        HStack(spacing: 8) {
                                            Circle()
                                                .fill(DesignSystem.Colors.primary)
                                                .frame(width: 12, height: 12)
                                            Text("🫖 Personalized for You")
                                                .font(.caption2)
                                                .foregroundColor(.primary)
                                        }
                                        
                                        HStack(spacing: 8) {
                                            Circle()
                                                .fill(DesignSystem.Colors.secondary)
                                                .frame(width: 12, height: 12)
                                            Text("☕ Community Spots")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .padding(8)
                                    .background(.ultraThinMaterial)
                                    .cornerRadius(8)
                                }
                                .padding()
                            }
                        }
                    )
            }
        }
    }
    
    private var listView: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("All Chai Spots")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(vm.allSpots.count) spots")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            
            Divider()
            
            // Spots list
            if vm.allSpots.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "cup.and.saucer")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    
                    Text("No spots yet")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("Be the first to add a chai spot!")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(vm.allSpots) { spot in
                            SpotRowView(
                                spot: spot, 
                                isPersonalized: vm.personalizedSpots.contains(where: { $0.id == spot.id }),
                                onTap: {
                                    selectedSpot = spot
                                }
                            )
                            
                            if spot.id != vm.allSpots.last?.id {
                                Divider()
                                    .padding(.leading, 16)
                            }
                        }
                    }
                }
            }
        }
    }
}

final class PersonalizedMapViewModel: ObservableObject {
    @Published var allSpots: [ChaiSpot] = []
    @Published var personalizedSpots: [ChaiSpot] = []
    @Published var reasonText: String?
    @Published var mapView: TappableMapView?
    @Published var isLoading = false
    @Published var hasError = false
    @Published var errorMessage: String?
    @Published var isShowingList = false {
        didSet {
            print("🔄 ViewModel isShowingList changed from \(oldValue) to \(isShowingList)")
        }
    }
    
    // Filter state
    @Published var showFriendsFavorites = true
    @Published var showHighlyRated = true
    @Published var showRecentlyReviewed = true
    @Published var sortOrder: SortOrder = .relevance
    
    // Sort order enum
    enum SortOrder: Int, CaseIterable {
        case relevance = 0
        case distance = 1
        case rating = 2
        case recent = 3
        
        var displayName: String {
            switch self {
            case .relevance: return "Relevance"
            case .distance: return "Distance"
            case .rating: return "Rating"
            case .recent: return "Recent"
            }
        }
    }
    
    private let queries = FirestoreQueries()
    private var onSpotSelected: ((ChaiSpot) -> Void)?
    
    func setSpotSelectionHandler(_ handler: @escaping (ChaiSpot) -> Void) {
        self.onSpotSelected = handler
    }
    
    // MARK: - Filter Methods
    
    func applyFilters() {
        print("🔍 Applying filters: friends=\(showFriendsFavorites), rated=\(showHighlyRated), recent=\(showRecentlyReviewed), sort=\(sortOrder.displayName)")
        
        // Filter spots based on current filter settings
        var filteredSpots = allSpots
        
        if showFriendsFavorites {
            // Keep spots that have friend ratings
            filteredSpots = filteredSpots.filter { spot in
                // This would need to be implemented based on your data structure
                // For now, we'll keep all spots
                return true
            }
        }
        
        if showHighlyRated {
            // Keep spots with high ratings (4.0+)
            filteredSpots = filteredSpots.filter { spot in
                return spot.averageRating >= 4.0
            }
        }
        
        if showRecentlyReviewed {
            // Keep spots reviewed in the last 30 days
            let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
            filteredSpots = filteredSpots.filter { spot in
                // This would need to be implemented based on your data structure
                // For now, we'll keep all spots
                return true
            }
        }
        
        // Sort spots based on current sort order
        filteredSpots = sortSpots(filteredSpots, by: sortOrder)
        
        // Update the map view with filtered spots
        Task {
            await MainActor.run {
                self.mapView = createMapView(with: filteredSpots, personalized: personalizedSpots)
            }
        }
    }
    
    private func sortSpots(_ spots: [ChaiSpot], by sortOrder: SortOrder) -> [ChaiSpot] {
        switch sortOrder {
        case .relevance:
            // Keep original order (already scored by relevance)
            return spots
        case .distance:
            // Sort by distance (would need user location)
            // For now, keep original order since we don't have distance calculated
            return spots
        case .rating:
            // Sort by rating (highest first)
            return spots.sorted { $0.averageRating > $1.averageRating }
        case .recent:
            // Sort by most recently added/updated
            return spots.sorted { $0.id > $1.id } // Simple ID-based sorting for now
        }
    }

    func load(for uid: String?) async {
        print("🚀 Starting to load personalized map for user: \(uid ?? "nil")")
        
        guard let uid = uid else { 
            print("❌ No user ID provided")
            await MainActor.run {
                self.hasError = true
                self.errorMessage = "User not authenticated. Please sign in again."
            }
            return 
        }
        
        // Check if user is authenticated
        guard Auth.auth().currentUser != nil else {
            print("❌ User not authenticated with Firebase")
            await MainActor.run {
                self.hasError = true
                self.errorMessage = "Authentication required. Please sign in again."
            }
            return
        }
        
        print("✅ User authentication verified")
        
        await MainActor.run {
            print("🔄 Setting loading state to true")
            self.isLoading = true
            self.hasError = false
            self.errorMessage = nil
        }
        
        do {
            print("📍 Step 1: Testing Firestore connection...")
            let db = Firestore.firestore()
            let testQuery = try await db.collection("chaiFinder").limit(to: 1).getDocuments()
            print("✅ Firestore connection successful, found \(testQuery.documents.count) test documents")
            
            print("📍 Step 2: Loading all chai spots...")
            let allSpots = try await loadAllChaiSpots()
            print("✅ Loaded \(allSpots.count) chai spots")
            
            if allSpots.isEmpty {
                print("⚠️ No chai spots found in database")
                await MainActor.run {
                    self.allSpots = []
                    self.personalizedSpots = []
                    self.mapView = nil
                    self.isLoading = false
                    self.reasonText = "No chai spots found yet"
                }
                return
            }
            
            print("👤 Step 3: Loading user profile and friends...")
            let (userProfile, friendIds) = try await loadUserProfileAndFriends(uid: uid)
            print("✅ User profile: \(userProfile?.hasTasteSetup ?? false), Friends: \(friendIds.count)")
            
            print("🎯 Step 4: Scoring spots...")
            let scoredSpots = scoreSpots(allSpots, userProfile: userProfile, friendIds: friendIds)
            print("✅ Scored \(scoredSpots.count) spots")
            
            print("🔀 Step 5: Separating personalized spots...")
            let (personalized, general) = separatePersonalizedSpots(scoredSpots)
            print("✅ Personalized: \(personalized.count), General: \(general.count)")
            
            print("🗺️ Step 6: Creating map view...")
            let mapView = createMapView(with: allSpots, personalized: personalized)
            print("✅ Map view created with \(allSpots.count) spots")
            
            // Fallback: if no personalized spots, show all spots as general
            let finalPersonalized = personalized.isEmpty ? [] : personalized
            let finalGeneral = personalized.isEmpty ? allSpots : general
            
            await MainActor.run {
                print("🔄 Setting final state - spots: \(allSpots.count), mapView: \(mapView != nil)")
                self.allSpots = allSpots
                self.personalizedSpots = finalPersonalized
                self.mapView = mapView
                self.isLoading = false
                
                if finalPersonalized.isEmpty {
                    self.reasonText = "Showing all \(allSpots.count) chai spots in your area"
                    print("✅ Showing \(allSpots.count) community spots")
                } else {
                    self.reasonText = "\(finalPersonalized.count) personalized spots + \(finalGeneral.count) community spots"
                    print("✅ Showing \(finalPersonalized.count) personalized + \(finalGeneral.count) community spots")
                }
                
                print("🎉 Map loading completed successfully!")
            }
        } catch {
            print("💥 Error loading map: \(error)")
            print("💥 Error details: \(error.localizedDescription)")
            
            let userFriendlyMessage: String
            if let nsError = error as NSError? {
                switch nsError.domain {
                case "FIRFirestoreErrorDomain":
                    switch nsError.code {
                    case 7: // Permission denied
                        userFriendlyMessage = "Permission denied. Please check your internet connection and try again."
                    case 13: // Unavailable
                        userFriendlyMessage = "Service temporarily unavailable. Please try again later."
                    case 16: // Unauthenticated
                        userFriendlyMessage = "Authentication required. Please sign in again."
                    default:
                        userFriendlyMessage = "Database error: \(nsError.localizedDescription)"
                    }
                case "NSURLErrorDomain":
                    userFriendlyMessage = "Network error. Please check your internet connection and try again."
                default:
                    userFriendlyMessage = "Failed to load chai spots: \(error.localizedDescription)"
                }
            } else {
                userFriendlyMessage = "Failed to load chai spots: \(error.localizedDescription)"
            }
            
            await MainActor.run {
                self.isLoading = false
                self.hasError = true
                self.errorMessage = userFriendlyMessage
            }
        }
    }
    
    // MARK: - Data Loading
    
    private func loadAllChaiSpots() async throws -> [ChaiSpot] {
        print("🔍 Attempting to load chai spots from Firestore...")
        
        let db = Firestore.firestore()
        
        do {
            let snapshot = try await db.collection("chaiFinder").getDocuments()
            print("🔍 Found \(snapshot.documents.count) documents in chaiFinder collection")
            
            if snapshot.documents.isEmpty {
                print("⚠️ chaiFinder collection is empty - no spots found")
                return []
            }
            
            let spots: [ChaiSpot] = snapshot.documents.compactMap { document in
                let data = document.data()
                print("📄 Document \(document.documentID): \(data)")
                
                guard let name = data["name"] as? String,
                      let address = data["address"] as? String,
                      let latitude = data["latitude"] as? Double,
                      let longitude = data["longitude"] as? Double,
                      let chaiTypes = data["chaiTypes"] as? [String] else {
                    print("❌ Failed to parse document \(document.documentID) - missing required fields")
                    print("❌ Required fields: name(\(type(of: data["name"]))), address(\(type(of: data["address"]))), latitude(\(type(of: data["latitude"]))), longitude(\(type(of: data["longitude"]))), chaiTypes(\(type(of: data["chaiTypes"])))")
                    return nil
                }
                
                let averageRating = data["averageRating"] as? Double ?? 0.0
                let ratingCount = data["ratingCount"] as? Int ?? 0
                
                print("✅ Successfully parsed: \(name)")
                
                return ChaiSpot(
                    id: document.documentID,
                    name: name,
                    address: address,
                    latitude: latitude,
                    longitude: longitude,
                    chaiTypes: chaiTypes,
                    averageRating: averageRating,
                    ratingCount: ratingCount
                )
            }
            
            print("📊 Successfully loaded \(spots.count) chai spots")
            return spots
            
        } catch let error as NSError {
            print("💥 Firestore error: \(error.localizedDescription)")
            print("💥 Error domain: \(error.domain)")
            print("💥 Error code: \(error.code)")
            print("💥 User info: \(error.userInfo)")
            throw error
        }
    }
    
    private func loadUserProfileAndFriends(uid: String) async throws -> (UserProfile?, [String]) {
        let db = Firestore.firestore()
        
        // Load user profile
        let userDoc = try await db.collection("users").document(uid).getDocument()
        
        var userProfile: UserProfile? = nil
        if userDoc.exists {
            do {
                userProfile = try userDoc.data(as: UserProfile.self)
                print("✅ User profile decoded successfully")
            } catch {
                print("⚠️ Failed to decode user profile: \(error)")
                print("⚠️ User profile data: \(userDoc.data() ?? [:])")
                // Continue without user profile - not critical for map loading
            }
        }
        
        // Load friends list from the same document
        let friendIds: [String] = userDoc.data()?["friends"] as? [String] ?? []
        
        print("👤 User profile loaded: \(userProfile?.hasTasteSetup ?? false)")
        print("👥 Friends count: \(friendIds.count)")
        
        return (userProfile, friendIds)
    }
    
    // MARK: - Personalization Algorithm
    
    private func scoreSpots(_ spots: [ChaiSpot], userProfile: UserProfile?, friendIds: [String]) -> [(ChaiSpot, Double)] {
        return spots.map { spot in
            var score: Double = 0.0
            
            // Base score from community rating
            score += spot.averageRating * 0.3
            
            // Boost for spots with more reviews (social proof)
            score += min(Double(spot.ratingCount) * 0.1, 2.0)
            
            // Taste matching (if user has taste profile)
            if let userProfile = userProfile,
               let topTasteTags = userProfile.topTasteTags {
                let tasteMatch = calculateTasteMatch(spot.chaiTypes, userTasteTags: topTasteTags)
                score += tasteMatch * 0.4
            }
            
            // Friends factor (if user has friends)
            if !friendIds.isEmpty {
                let friendsFactor = calculateFriendsFactor(spot, friendIds: friendIds)
                score += friendsFactor * 0.3
            }
            
            return (spot, score)
        }.sorted { $0.1 > $1.1 } // Sort by score descending
    }
    
    private func calculateTasteMatch(_ spotChaiTypes: [String], userTasteTags: [String]) -> Double {
        let intersection = Set(spotChaiTypes).intersection(Set(userTasteTags))
        return Double(intersection.count) / Double(max(userTasteTags.count, 1))
    }
    
    private func calculateFriendsFactor(_ spot: ChaiSpot, friendIds: [String]) -> Double {
        // This would ideally query friends' reviews for this spot
        // For now, return a base score that can be enhanced later
        return 0.5 // Placeholder - will be enhanced with actual friend data
    }
    
    private func separatePersonalizedSpots(_ scoredSpots: [(ChaiSpot, Double)]) -> ([ChaiSpot], [ChaiSpot]) {
        let threshold = 1.5 // Lowered threshold for "personalized" spots
        
        let personalized = scoredSpots.filter { $0.1 >= threshold }.map { $0.0 }
        let general = scoredSpots.filter { $0.1 < threshold }.map { $0.0 }
        
        // Debug: Print scores to understand what's happening
        print("🔍 Scored spots:")
        for (spot, score) in scoredSpots.prefix(5) {
            print("  \(spot.name): \(String(format: "%.2f", score)) \(score >= threshold ? "✅ Personalized" : "❌ General")")
        }
        print("📊 Total: \(scoredSpots.count) spots, \(personalized.count) personalized, \(general.count) general")
        
        return (personalized, general)
    }
    
    private func createMapView(with allSpots: [ChaiSpot], personalized: [ChaiSpot]) -> TappableMapView {
        print("🗺️ Creating map view with \(allSpots.count) spots")
        
        // Convert ChaiSpot to ChaiFinder for the map view
        let chaiFinderSpots = allSpots.map { spot in
            ChaiFinder(
                id: spot.id,
                name: spot.name,
                latitude: spot.latitude,
                longitude: spot.longitude,
                address: spot.address,
                chaiTypes: spot.chaiTypes,
                averageRating: spot.averageRating,
                ratingCount: spot.ratingCount
            )
        }
        
        print("✅ Converted \(chaiFinderSpots.count) spots to ChaiFinder")
        
        // Create a region that encompasses all spots
        let region = calculateRegion(for: allSpots)
        print("📍 Map region: center \(region.center.latitude), \(region.center.longitude), span \(region.span.latitudeDelta), \(region.span.longitudeDelta)")
        
        return TappableMapView(
            region: Binding.constant(region),
            chaiFinder: chaiFinderSpots,
            personalizedSpotIds: Set(personalized.map { $0.id }),
            onTap: { coordinate in
                // Handle map tap
                print("Map tapped at: \(coordinate)")
            },
            onAnnotationTap: { spotId in
                // Handle annotation tap - show detail sheet
                print("Annotation tapped for spot: \(spotId)")
                if let spot = allSpots.first(where: { $0.id == spotId }) {
                    self.onSpotSelected?(spot)
                }
            }
        )
    }
    
    private func calculateRegion(for spots: [ChaiSpot]) -> MKCoordinateRegion {
        guard !spots.isEmpty else {
            // Default to a reasonable region if no spots
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194), // San Francisco
                span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
            )
        }
        
        let latitudes = spots.map { $0.latitude }
        let longitudes = spots.map { $0.longitude }
        
        let minLat = latitudes.min() ?? 0
        let maxLat = latitudes.max() ?? 0
        let minLon = longitudes.min() ?? 0
        let maxLon = longitudes.max() ?? 0
        
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        
        let span = MKCoordinateSpan(
            latitudeDelta: (maxLat - minLat) * 1.2, // Add 20% padding
            longitudeDelta: (maxLon - minLon) * 1.2
        )
        
        return MKCoordinateRegion(center: center, span: span)
    }
    
    func centerOnUser() {
        // TODO: Implement map centering on user location
        HapticManager.light()
    }
    
    func zoomToFit() {
        // TODO: Implement map zoom to fit all spots
        HapticManager.light()
    }
}

// Spot detail sheet
struct SpotDetailSheet: View {
    let spot: ChaiSpot
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text(spot.name)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(spot.address)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    
                    Divider()
                    
                    // Chai Types
                    if !spot.chaiTypes.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Chai Types")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                                ForEach(spot.chaiTypes, id: \.self) { chaiType in
                                    Text(chaiType)
                                        .font(.caption)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(DesignSystem.Colors.primary.opacity(0.1))
                                        .foregroundColor(DesignSystem.Colors.primary)
                                        .cornerRadius(8)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    // Rating
                    if spot.averageRating > 0 {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Rating")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            HStack(spacing: 8) {
                                HStack(spacing: 4) {
                                    Image(systemName: "star.fill")
                                        .foregroundColor(.yellow)
                                    Text(String(format: "%.1f", spot.averageRating))
                                        .fontWeight(.semibold)
                                }
                                
                                Text("(\(spot.ratingCount) reviews)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    // Location
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Location")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        HStack {
                            Image(systemName: "location")
                                .foregroundColor(.secondary)
                            Text("\(spot.latitude, specifier: "%.4f"), \(spot.longitude, specifier: "%.4f")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                    }
                    
                    Spacer(minLength: 100)
                }
                .padding(.vertical)
            }
            .navigationTitle("Spot Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// Help view for map usage
struct MapHelpView: View {
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HelpSection(
                        title: "How it works",
                        content: "Your map shows chai spots personalized to your taste preferences and friends' recommendations."
                    )
                    
                    HelpSection(
                        title: "Understanding the spots",
                        content: "Each spot is ranked based on your taste profile, friends' ratings, proximity, and recent activity."
                    )
                    
                    HelpSection(
                        title: "Getting better recommendations",
                        content: "Add friends, rate spots you visit, and update your taste preferences to improve your personalized experience."
                    )
                }
                .padding()
            }
            .navigationTitle("Map Help")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        // Dismiss
                    }
                }
            }
        }
    }
}

private struct HelpSection: View {
    let title: String
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
            
            Text(content)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

// Filters view for map customization
struct MapFiltersView: View {
    @ObservedObject var viewModel: PersonalizedMapViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Sort by") {
                    Picker("Sort order", selection: $viewModel.sortOrder) {
                        ForEach(PersonalizedMapViewModel.SortOrder.allCases, id: \.self) { sortOrder in
                            Text(sortOrder.displayName).tag(sortOrder)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: viewModel.sortOrder) { _ in
                        viewModel.applyFilters()
                    }
                }
                
                Section("Filters") {
                    Toggle("Friends' favorites", isOn: $viewModel.showFriendsFavorites)
                        .onChange(of: viewModel.showFriendsFavorites) { _ in
                            viewModel.applyFilters()
                        }
                    
                    Toggle("Highly rated", isOn: $viewModel.showHighlyRated)
                        .onChange(of: viewModel.showHighlyRated) { _ in
                            viewModel.applyFilters()
                        }
                    
                    Toggle("Recently reviewed", isOn: $viewModel.showRecentlyReviewed)
                        .onChange(of: viewModel.showRecentlyReviewed) { _ in
                            viewModel.applyFilters()
                        }
                }
            }
            .navigationTitle("Map Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// Haptic feedback manager
private struct HapticManager {
    static func light() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
}

// Spot row view for the list
private struct SpotRowView: View {
    let spot: ChaiSpot
    let isPersonalized: Bool
    let onTap: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Personalized indicator
            if isPersonalized {
                Circle()
                    .fill(DesignSystem.Colors.primary)
                    .frame(width: 8, height: 8)
            } else {
                Circle()
                    .fill(DesignSystem.Colors.secondary)
                    .frame(width: 8, height: 8)
            }
            
            // Spot info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(spot.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    if isPersonalized {
                        Text("★")
                            .font(.caption)
                            .foregroundColor(DesignSystem.Colors.primary)
                    }
                }
                
                Text(spot.address)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                if !spot.chaiTypes.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(spot.chaiTypes.prefix(3), id: \.self) { chaiType in
                            Text(chaiType)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(DesignSystem.Colors.primary.opacity(0.1))
                                .foregroundColor(DesignSystem.Colors.primary)
                                .cornerRadius(4)
                        }
                        
                        if spot.chaiTypes.count > 3 {
                            Text("+\(spot.chaiTypes.count - 3)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            Spacer()
            
            // Rating
            if spot.averageRating > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundColor(.yellow)
                    
                    Text(String(format: "%.1f", spot.averageRating))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .onTapGesture {
            onTap()
        }
    }
}
