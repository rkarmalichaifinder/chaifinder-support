import SwiftUI
import MapKit
import CoreLocation
import Firebase
import FirebaseFirestore

struct PersonalizedMapView: View {
    @StateObject private var vm = PersonalizedMapViewModel()
    @EnvironmentObject var session: SessionStore
    // Map region - only used for initial setup
    @State private var initialRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    
    // Location manager for distance sorting
    @State private var locationManager = CLLocationManager()
    @State private var locationDelegate: LocationManagerDelegate?
    
    // Spot detail navigation
    @State private var selectedSpot: ChaiSpot?
    @State private var showingSpotDetail = false
    
    // Map interaction state
    @State private var isUserInteractingWithMap = false
    
    // Map view reference for programmatic updates
    @State private var mapViewRef: MKMapView?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with toggle
                headerSection
                
                // Map legend (only show when map is visible)
                if !vm.isShowingList {
                    mapLegend
                }
                
                // Map or List view
                if vm.isShowingList {
                    listView
                } else {
                    mapView
                }
            }
            .background(DesignSystem.Colors.background)
            .navigationTitle("My Chai Map")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                print("🎯 PersonalizedMapView appeared")
                setupLocationManager()
                vm.loadPersonalizedSpots()
            }
            .task {
                print("🚀 PersonalizedMapView task started")
                await vm.loadAllSpots()
                print("🚀 PersonalizedMapView task completed")
            }
            .sheet(isPresented: $showingSpotDetail) {
                if let spot = selectedSpot {
                    ChaiSpotDetailSheet(spot: spot, userLocation: locationManager.location)
                }
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            // View toggle
            HStack {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        vm.isShowingList = false
                    }
                }) {
                    HStack {
                        Image(systemName: "map")
                        Text("Map")
                    }
                    .foregroundColor(vm.isShowingList ? DesignSystem.Colors.textSecondary : DesignSystem.Colors.primary)
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.vertical, DesignSystem.Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                            .fill(vm.isShowingList ? Color.clear : DesignSystem.Colors.primary.opacity(0.1))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                            .stroke(vm.isShowingList ? DesignSystem.Colors.border : DesignSystem.Colors.primary, lineWidth: 1)
                    )
                }
                
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        vm.isShowingList = true
                    }
                }) {
                    HStack {
                        Image(systemName: "list.bullet")
                        Text("List")
                    }
                    .foregroundColor(vm.isShowingList ? DesignSystem.Colors.primary : DesignSystem.Colors.textSecondary)
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.vertical, DesignSystem.Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                            .fill(vm.isShowingList ? DesignSystem.Colors.primary.opacity(0.1) : Color.clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                            .stroke(vm.isShowingList ? DesignSystem.Colors.primary : DesignSystem.Colors.border, lineWidth: 1)
                    )
                }
                
                Spacer()
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            
            // Personalization reason
            if let reason = vm.reasonText {
                HStack {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(DesignSystem.Colors.accent)
                    Text(reason)
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .multilineTextAlignment(.leading)
                    Spacer()
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.cardBackground)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(DesignSystem.Colors.border),
            alignment: .bottom
        )
    }
    
    // MARK: - Map Legend
    private var mapLegend: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Personalized spots legend
            HStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: "circle.fill")
                    .foregroundColor(DesignSystem.Colors.primary)
                    .font(.caption)
                Text("🫖 Your Spots")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
            
            // Community spots legend
            HStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: "circle.fill")
                    .foregroundColor(DesignSystem.Colors.secondary)
                    .font(.caption)
                Text("☕ Community Spots")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
            
            Spacer()
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .background(DesignSystem.Colors.cardBackground.opacity(0.8))
        .cornerRadius(DesignSystem.CornerRadius.small)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                .stroke(DesignSystem.Colors.border, lineWidth: 0.5)
        )
    }
    
    // MARK: - Map View
    private var mapView: some View {
        ZStack {
            if vm.allSpots.isEmpty {
                // Loading state
                VStack {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Loading map...")
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .padding(.top, DesignSystem.Spacing.md)
                }
            } else {
                // Create map view with spots
                TappableMapView(
                    initialRegion: initialRegion,
                    chaiFinder: vm.allSpots.map { spot in
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
                    },
                    onTap: { coordinate in
                        // Handle map tap
                        print("📍 Map tapped at: \(coordinate)")
                        // Set user interaction flag when map is tapped
                        isUserInteractingWithMap = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            isUserInteractingWithMap = false
                        }
                    },
                    onAnnotationTap: { spotId in
                        // Handle spot annotation tap
                        if let spot = vm.allSpots.first(where: { $0.id == spotId }) {
                            print("📍 Spot selected from map: \(spot.name)")
                            selectedSpot = spot
                            showingSpotDetail = true
                        }
                    },
                    onMapViewCreated: { mapView in
                        // Store reference to map view for programmatic updates
                        self.mapViewRef = mapView
                    }
                )
            }
        }
    }
    
    // MARK: - List View
    private var listView: some View {
        VStack(spacing: 0) {
            // Sort options
            sortOptionsSection
            
            // Spots list
            if vm.isLoading {
                LoadingView("Loading spots...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if vm.personalizedSpots.isEmpty {
                emptyStateView
            } else {
                spotsList
            }
        }
    }
    
    private var sortOptionsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignSystem.Spacing.md) {
                ForEach(PersonalizedMapViewModel.SortOrder.allCases, id: \.self) { sortOrder in
                    Button(action: {
                        vm.sortSpots(by: sortOrder)
                    }) {
                        Text(sortOrder.displayName)
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(vm.currentSortOrder == sortOrder ? .white : DesignSystem.Colors.primary)
                            .padding(.horizontal, DesignSystem.Spacing.md)
                            .padding(.vertical, DesignSystem.Spacing.sm)
                            .background(
                                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                                    .fill(vm.currentSortOrder == sortOrder ? DesignSystem.Colors.primary : Color.clear)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                                    .stroke(DesignSystem.Colors.primary, lineWidth: 1)
                            )
                    }
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
        }
        .padding(.vertical, DesignSystem.Spacing.md)
    }
    
    private var spotsList: some View {
        ScrollView {
            LazyVStack(spacing: DesignSystem.Spacing.md) {
                ForEach(vm.personalizedSpots) { spot in
                    SpotCard(spot: spot) {
                        // Handle spot selection - center map on selected spot and show details
                        print("📍 Spot selected from list: \(spot.name)")
                        selectedSpot = spot
                        showingSpotDetail = true
                        centerMapOnSpot(spot)
                        // Switch to map view to show the selected spot
                        withAnimation(.easeInOut(duration: 0.3)) {
                            vm.isShowingList = false
                        }
                    }
                }
            }
            .padding(DesignSystem.Spacing.lg)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 48))
                .foregroundColor(DesignSystem.Colors.secondary)
            
            Text("No Spots Found")
                .font(DesignSystem.Typography.headline)
                .fontWeight(.bold)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            
            Text("Try adjusting your preferences or check back later")
                .font(DesignSystem.Typography.bodyMedium)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(DesignSystem.Spacing.xl)
    }
    
    // MARK: - Location Manager Setup
    private func setupLocationManager() {
        // Request location access for distance sorting
        locationDelegate = LocationManagerDelegate(
            viewModel: vm, 
            onLocationUpdate: { location in
                self.centerMapOnLocation(location)
            },
            checkUserInteraction: {
                self.isUserInteractingWithMap
            }
        )
        locationManager.delegate = locationDelegate
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
        
        // If we already have location, center the map
        if let location = locationManager.location {
            vm.updateUserLocation(location)
            centerMapOnLocation(location)
        }
    }
    
    private func centerMapOnLocation(_ location: CLLocation) {
        guard let mapView = mapViewRef else { return }
        
        let newRegion = MKCoordinateRegion(
            center: location.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03)
        )
        
        withAnimation(.easeInOut(duration: 0.5)) {
            mapView.setRegion(newRegion, animated: true)
        }
    }
    
    private func centerMapOnSpot(_ spot: ChaiSpot) {
        guard let mapView = mapViewRef else { return }
        
        let newRegion = MKCoordinateRegion(
            center: spot.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
        )
        
        withAnimation(.easeInOut(duration: 0.5)) {
            mapView.setRegion(newRegion, animated: true)
        }
    }
}

    // MARK: - Location Manager Delegate
    class LocationManagerDelegate: NSObject, CLLocationManagerDelegate {
        let viewModel: PersonalizedMapViewModel
        let onLocationUpdate: (CLLocation) -> Void
        let checkUserInteraction: () -> Bool
        
        init(viewModel: PersonalizedMapViewModel, onLocationUpdate: @escaping (CLLocation) -> Void, checkUserInteraction: @escaping () -> Bool) {
            self.viewModel = viewModel
            self.onLocationUpdate = onLocationUpdate
            self.checkUserInteraction = checkUserInteraction
        }
        
        func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
            if let location = locations.last {
                viewModel.updateUserLocation(location)
                
                // Only center map if user is not interacting with it
                if !checkUserInteraction() {
                    onLocationUpdate(location)
                }
            }
        }
        
        func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
            print("❌ Location manager failed: \(error.localizedDescription)")
        }
    }

// MARK: - Spot Card
struct SpotCard: View {
    let spot: ChaiSpot
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DesignSystem.Spacing.md) {
                // Spot icon
                Image(systemName: "mappin.circle.fill")
                    .font(.title2)
                    .foregroundColor(DesignSystem.Colors.primary)
                
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text(spot.name)
                        .font(DesignSystem.Typography.bodyMedium)
                        .fontWeight(.medium)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .lineLimit(1)
                    
                    Text(spot.address)
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .lineLimit(1)
                    
                    if spot.averageRating > 0 {
                        HStack(spacing: DesignSystem.Spacing.xs) {
                            Image(systemName: "star.fill")
                                .font(.caption)
                                .foregroundColor(DesignSystem.Colors.accent)
                            Text(String(format: "%.1f", spot.averageRating))
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                            Text("(\(spot.ratingCount))")
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
            .padding(DesignSystem.Spacing.md)
            .background(DesignSystem.Colors.cardBackground)
            .cornerRadius(DesignSystem.CornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                    .stroke(DesignSystem.Colors.border, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Personalized Map View Model
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
    @Published var userLocation: CLLocation? // Added this line
    
    // Filter state
    @Published var showFriendsFavorites = true
    @Published var showPersonalizedOnly = true
    @Published var currentSortOrder: SortOrder = .personalization
    
    // Callback for spot selection
    private var onSpotSelected: ((ChaiSpot) -> Void)?
    
    enum SortOrder: CaseIterable {
        case personalization
        case distance
        case rating
        case name
        
        var displayName: String {
            switch self {
            case .personalization: return "Personalized"
            case .distance: return "Distance"
            case .rating: return "Rating"
            case .name: return "Name"
            }
        }
    }
    
    func setSpotSelectionHandler(_ handler: @escaping (ChaiSpot) -> Void) {
        self.onSpotSelected = handler
    }
    
    func updateUserLocation(_ location: CLLocation) { // Added this method
        self.userLocation = location
    }
    
    // MARK: - Filter Methods
    func toggleFriendsFavorites() {
        showFriendsFavorites.toggle()
        applyFilters()
    }
    
    func togglePersonalizedOnly() {
        showPersonalizedOnly.toggle()
        applyFilters()
    }
    
    private func applyFilters() {
        var filtered = allSpots
        
        if showPersonalizedOnly {
            // Apply personalization logic here
            filtered = filtered.filter { spot in
                // Add your personalization logic
                return true
            }
        }
        
        personalizedSpots = filtered
        sortSpots(by: currentSortOrder)
    }
    
    // MARK: - Sorting
    func sortSpots(by sortOrder: SortOrder) {
        currentSortOrder = sortOrder
        
        switch sortOrder {
        case .personalization:
            // Sort by personalization score (implement your logic)
            personalizedSpots.sort { $0.name < $1.name }
            
        case .distance:
            guard let userLocation = self.userLocation else {
                // If no user location, fall back to name sorting
                personalizedSpots.sort { $0.name < $1.name }
                return
            }
            
            personalizedSpots.sort { spot1, spot2 in
                let location1 = CLLocation(latitude: spot1.latitude, longitude: spot1.longitude)
                let location2 = CLLocation(latitude: spot2.latitude, longitude: spot2.longitude)
                
                let distance1 = userLocation.distance(from: location1)
                let distance2 = userLocation.distance(from: location2)
                
                return distance1 < distance2
            }
            
        case .rating:
            personalizedSpots.sort { $0.averageRating > $1.averageRating }
            
        case .name:
            personalizedSpots.sort { $0.name < $1.name }
        }
    }
    
    // MARK: - Data Loading
    func loadAllSpots() async {
        await MainActor.run {
            isLoading = true
        }
        
        let db = Firestore.firestore()
        var allSpots: [ChaiSpot] = []
        
        // Try both collections - chaiFinder and chaiSpots
        let collections = ["chaiFinder", "chaiSpots"]
        
        for collectionName in collections {
            do {
                let snapshot = try await db.collection(collectionName).getDocuments()
                
                let spots = snapshot.documents.compactMap { document -> ChaiSpot? in
                    let data = document.data()
                    
                    guard let name = data["name"] as? String,
                          let address = data["address"] as? String,
                          let latitude = data["latitude"] as? Double,
                          let longitude = data["longitude"] as? Double,
                          let chaiTypes = data["chaiTypes"] as? [String] else {
                        return nil
                    }
                    
                    let averageRating = data["averageRating"] as? Double ?? 0.0
                    let ratingCount = data["ratingCount"] as? Int ?? 0
                    
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
                
                allSpots.append(contentsOf: spots)
                
            } catch {
                print("Error loading from collection \(collectionName): \(error)")
                continue
            }
        }
        
        // Remove duplicates based on spot ID
        let uniqueSpots = Array(Set(allSpots))
        
        await MainActor.run {
            self.allSpots = uniqueSpots
            self.personalizedSpots = uniqueSpots
            self.isLoading = false
            self.applyFilters()
        }
    }
    
    func loadPersonalizedSpots() {
        // This would implement your personalization logic
        // For now, just use all spots
        personalizedSpots = allSpots
        reasonText = "Showing spots based on your preferences"
    }
}

struct PersonalizedMapView_Previews: PreviewProvider {
    static var previews: some View {
        PersonalizedMapView()
            .environmentObject(SessionStore())
    }
}
