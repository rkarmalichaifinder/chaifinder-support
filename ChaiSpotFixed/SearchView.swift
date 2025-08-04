import SwiftUI
import MapKit
import Firebase
import FirebaseFirestore
import FirebaseFirestoreSwift
import CoreLocation

struct SearchView: View {
    @State private var isMapView = true
    @State private var searchText = ""
    @State private var chaiSpots: [ChaiSpot] = []
    @State private var isLoading = false
    @StateObject private var locationManager = LocationManager()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: DesignSystem.Spacing.md) {
                    Text("Search")
                        .font(DesignSystem.Typography.titleMedium)
                        .fontWeight(.bold)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    
                    // View Toggle
                    HStack(spacing: 0) {
                        Button(action: { isMapView = true }) {
                            Text("Map View")
                                .font(DesignSystem.Typography.bodyMedium)
                                .fontWeight(.medium)
                                .foregroundColor(isMapView ? .white : DesignSystem.Colors.textSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, DesignSystem.Spacing.md)
                                .background(isMapView ? DesignSystem.Colors.primary : DesignSystem.Colors.secondary)
                        }
                        
                        Button(action: { isMapView = false }) {
                            Text("List View")
                                .font(DesignSystem.Typography.bodyMedium)
                                .fontWeight(.medium)
                                .foregroundColor(!isMapView ? .white : DesignSystem.Colors.textSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, DesignSystem.Spacing.md)
                                .background(!isMapView ? DesignSystem.Colors.primary : DesignSystem.Colors.secondary)
                        }
                    }
                    .cornerRadius(DesignSystem.CornerRadius.medium)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                            .stroke(DesignSystem.Colors.border, lineWidth: 1)
                    )
                    
                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .font(.system(size: 16))
                        
                        TextField("Search for a chai spot, type, etc.", text: $searchText)
                            .font(DesignSystem.Typography.bodyMedium)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                            .onChange(of: searchText) { newValue in
                                // Debounce the search to avoid state modification during view updates
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    if searchText == newValue {
                                        searchChaiSpots()
                                    }
                                }
                            }
                        
                        if !searchText.isEmpty {
                            Button(action: { 
                                DispatchQueue.main.async {
                                    searchText = ""
                                    loadAllChaiSpots()
                                }
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                                    .font(.system(size: 16))
                            }
                        }
                    }
                    .padding(DesignSystem.Spacing.md)
                    .background(DesignSystem.Colors.searchBackground)
                    .cornerRadius(DesignSystem.CornerRadius.large)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                            .stroke(DesignSystem.Colors.border, lineWidth: 1)
                    )
                }
                .padding(DesignSystem.Spacing.lg)
                .background(DesignSystem.Colors.background)
                
                // Content
                VStack(spacing: 0) {
                    if isMapView {
                        MapSearchView(searchText: $searchText, chaiSpots: $chaiSpots, locationManager: locationManager)
                    } else {
                        ListSearchView(searchText: $searchText, chaiSpots: $chaiSpots, locationManager: locationManager)
                    }
                    Spacer(minLength: 0)
                }
            }
            .background(DesignSystem.Colors.background)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped() // Ensure content doesn't overflow
            .navigationBarHidden(true)
            .onAppear {
                loadAllChaiSpots()
            }
        }
    }
    
    private func searchChaiSpots() {
        guard !searchText.isEmpty else {
            loadAllChaiSpots()
            return
        }
        
        // Check if it's a location-based search (zip code or city)
        let isLocationSearch = (searchText.count == 5 && Int(searchText) != nil) || 
                              searchText.range(of: "^[A-Za-z\\s]+$", options: .regularExpression) != nil
        
        if isLocationSearch {
            // For location searches, load all spots and let ListSearchView handle filtering
            loadAllChaiSpots()
        } else {
            // For name/address searches, search the database
            searchByNameAndAddress()
        }
    }
    
    private func searchByNameAndAddress() {
        isLoading = true
        let db = Firestore.firestore()
        
        // First, try to search by name
        db.collection("chaiFinder")
            .whereField("name", isGreaterThanOrEqualTo: searchText)
            .whereField("name", isLessThan: searchText + "\u{f8ff}")
            .getDocuments { snapshot, error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("Error searching by name: \(error.localizedDescription)")
                        // If name search fails, try address search
                        self.searchByAddress()
                        return
                    }
                    
                    guard let documents = snapshot?.documents else {
                        // If no results by name, try address search
                        self.searchByAddress()
                        return
                    }
                    
                    let nameResults = self.processSearchResults(documents)
                    
                    // If we found results by name, use them
                    if !nameResults.isEmpty {
                        self.chaiSpots = nameResults
                        self.isLoading = false
                    } else {
                        // If no name results, try address search
                        self.searchByAddress()
                    }
                }
            }
    }
    
    private func searchByAddress() {
        let db = Firestore.firestore()
        
        // Search by address (case-insensitive)
        db.collection("chaiFinder")
            .whereField("address", isGreaterThanOrEqualTo: searchText)
            .whereField("address", isLessThan: searchText + "\u{f8ff}")
            .getDocuments { snapshot, error in
                DispatchQueue.main.async {
                    self.isLoading = false
                    
                    if let error = error {
                        print("Error searching by address: \(error.localizedDescription)")
                        self.chaiSpots = []
                        return
                    }
                    
                    guard let documents = snapshot?.documents else {
                        self.chaiSpots = []
                        return
                    }
                    
                    self.chaiSpots = self.processSearchResults(documents)
                }
            }
    }
    
    private func loadAllChaiSpots() {
        isLoading = true
        let db = Firestore.firestore()
        
        print("🔄 Loading all chai spots from Firestore...")
        
        db.collection("chaiFinder").getDocuments { snapshot, error in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    print("❌ Error loading chai spots: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("❌ No documents found in chaiFinder collection")
                    self.chaiSpots = []
                    return
                }
                
                print("📄 Found \(documents.count) documents in chaiFinder collection")
                
                self.chaiSpots = self.processSearchResults(documents)
                print("✅ Processed \(self.chaiSpots.count) chai spots")
            }
        }
    }
    
    private func processSearchResults(_ documents: [QueryDocumentSnapshot]) -> [ChaiSpot] {
        return documents.compactMap { document in
            guard let data = document.data() as? [String: Any],
                  let name = data["name"] as? String,
                  let latitude = data["latitude"] as? Double,
                  let longitude = data["longitude"] as? Double,
                  let address = data["address"] as? String else {
                print("⚠️ Skipping document \(document.documentID) - missing required fields")
                return nil
            }
            
            let chaiTypes = data["chaiTypes"] as? [String] ?? []
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
    }
} 

// MARK: - Map Search View
struct MapSearchView: View {
    @Binding var searchText: String
    @Binding var chaiSpots: [ChaiSpot]
    @ObservedObject var locationManager: LocationManager
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194), // Default to San Francisco
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    @State private var selectedSpot: ChaiSpot?
    @State private var showingSpotDetail = false
    @State private var searchLocation: CLLocation?
    @State private var isGeocoding = false
    
    var body: some View {
        ZStack {
            Map(coordinateRegion: $region, annotationItems: chaiSpots) { spot in
                MapAnnotation(coordinate: spot.coordinate) {
                    Button(action: {
                        selectedSpot = spot
                        showingSpotDetail = true
                    }) {
                        VStack(spacing: 2) {
                            Image(systemName: "cup.and.saucer.fill")
                                .foregroundColor(DesignSystem.Colors.primary)
                                .font(.title2)
                                .background(
                                    Circle()
                                        .fill(.white)
                                        .frame(width: 30, height: 30)
                                )
                                .shadow(
                                    color: DesignSystem.Shadows.small.color,
                                    radius: DesignSystem.Shadows.small.radius,
                                    x: DesignSystem.Shadows.small.x,
                                    y: DesignSystem.Shadows.small.y
                                )
                            
                            Text(spot.name)
                                .font(DesignSystem.Typography.caption)
                                .fontWeight(.medium)
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(.white)
                                .cornerRadius(DesignSystem.CornerRadius.small)
                                .shadow(
                                    color: DesignSystem.Shadows.small.color,
                                    radius: DesignSystem.Shadows.small.radius,
                                    x: DesignSystem.Shadows.small.x,
                                    y: DesignSystem.Shadows.small.y
                                )
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .allowsHitTesting(true) // Ensure proper touch handling
            // Remove ignoresSafeArea to prevent map from covering bottom tab bar
                    .onReceive(locationManager.$location) { location in
            // Only center on user location if no search location is set
            if searchLocation == nil, let location = location {
                DispatchQueue.main.async {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        region = MKCoordinateRegion(
                            center: location.coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                        )
                    }
                }
            }
        }
            
            // Location Button
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        // Clear search location and center on user location
                        searchLocation = nil
                        locationManager.requestLocation()
                    }) {
                        Image(systemName: "location.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(DesignSystem.Colors.primary)
                            .clipShape(Circle())
                            .shadow(
                                color: DesignSystem.Shadows.medium.color,
                                radius: DesignSystem.Shadows.medium.radius,
                                x: DesignSystem.Shadows.medium.x,
                                y: DesignSystem.Shadows.medium.y
                            )
                    }
                    .padding(DesignSystem.Spacing.lg)
                }
                Spacer()
            }
            
            // Floating Action Button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: {
                        // Add new chai spot
                    }) {
                        Image(systemName: "plus")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 56, height: 56)
                            .background(DesignSystem.Colors.primary)
                            .clipShape(Circle())
                            .shadow(
                                color: DesignSystem.Shadows.medium.color,
                                radius: DesignSystem.Shadows.medium.radius,
                                x: DesignSystem.Shadows.medium.x,
                                y: DesignSystem.Shadows.medium.y
                            )
                    }
                    .padding(DesignSystem.Spacing.lg)
                }
            }
        }
        .clipped() // Ensure the map doesn't overflow its bounds
        .onAppear {
            locationManager.requestLocation()
        }
        .onDisappear {
            // Clean up Metal resources when view disappears
            // This helps prevent the Metal assertion crash
        }
        .onChange(of: searchText) { newValue in
            // Debounce the geocoding to avoid state modification during view updates
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if searchText == newValue {
                    geocodeSearchLocation(newValue)
                }
            }
        }
        .sheet(isPresented: $showingSpotDetail) {
            if let spot = selectedSpot {
                ChaiSpotDetailSheet(spot: spot, userLocation: locationManager.location)
            }
        }
    }
    
    private func geocodeSearchLocation(_ searchText: String) {
        guard !searchText.isEmpty else {
            searchLocation = nil
            return
        }
        
        // Check if it looks like a zip code (5 digits)
        if searchText.count == 5, let _ = Int(searchText) {
            geocodeZipCode(searchText)
            return
        }
        
        // Check if it looks like a city name (contains letters and possibly spaces)
        if searchText.range(of: "^[A-Za-z\\s]+$", options: .regularExpression) != nil {
            geocodeCity(searchText)
            return
        }
        
        // For other searches, try general geocoding
        geocodeGeneral(searchText)
    }
    
    private func geocodeZipCode(_ zipCode: String) {
        isGeocoding = true
        let geocoder = CLGeocoder()
        
        geocoder.geocodeAddressString(zipCode) { placemarks, error in
            DispatchQueue.main.async {
                self.isGeocoding = false
                
                if let error = error {
                    print("Geocoding error for zip code \(zipCode): \(error.localizedDescription)")
                    return
                }
                
                if let location = placemarks?.first?.location {
                    self.searchLocation = location
                    print("Map: Found location for zip code \(zipCode): \(location.coordinate)")
                    
                    // Center map on the searched location
                    withAnimation(.easeInOut(duration: 0.5)) {
                        self.region = MKCoordinateRegion(
                            center: location.coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                        )
                    }
                }
            }
        }
    }
    
    private func geocodeCity(_ cityName: String) {
        isGeocoding = true
        let geocoder = CLGeocoder()
        
        geocoder.geocodeAddressString(cityName) { placemarks, error in
            DispatchQueue.main.async {
                self.isGeocoding = false
                
                if let error = error {
                    print("Geocoding error for city \(cityName): \(error.localizedDescription)")
                    return
                }
                
                if let location = placemarks?.first?.location {
                    self.searchLocation = location
                    print("Map: Found location for city \(cityName): \(location.coordinate)")
                    
                    // Center map on the searched location
                    withAnimation(.easeInOut(duration: 0.5)) {
                        self.region = MKCoordinateRegion(
                            center: location.coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                        )
                    }
                }
            }
        }
    }
    
    private func geocodeGeneral(_ searchText: String) {
        isGeocoding = true
        let geocoder = CLGeocoder()
        
        geocoder.geocodeAddressString(searchText) { placemarks, error in
            DispatchQueue.main.async {
                self.isGeocoding = false
                
                if let error = error {
                    print("Geocoding error for \(searchText): \(error.localizedDescription)")
                    return
                }
                
                if let location = placemarks?.first?.location {
                    self.searchLocation = location
                    print("Map: Found location for \(searchText): \(location.coordinate)")
                    
                    // Center map on the searched location
                    withAnimation(.easeInOut(duration: 0.5)) {
                        self.region = MKCoordinateRegion(
                            center: location.coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Location Manager
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    @Published var location: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    func requestLocation() {
        switch authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.requestLocation()
        default:
            break
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        self.location = location
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        authorizationStatus = status
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            locationManager.requestLocation()
        }
    }
}

// MARK: - List Search View
struct ListSearchView: View {
    @Binding var searchText: String
    @Binding var chaiSpots: [ChaiSpot]
    @ObservedObject var locationManager: LocationManager
    @State private var searchLocation: CLLocation?
    @State private var isGeocoding = false
    @State private var filteredSpots: [ChaiSpot] = []
    
    var sortedChaiSpots: [ChaiSpot] {
        // If we have a search location, filter and sort by distance from that location
        if let searchLocation = searchLocation {
            return filteredSpots.sorted { spot1, spot2 in
                let distance1 = searchLocation.distance(from: CLLocation(latitude: spot1.latitude, longitude: spot1.longitude))
                let distance2 = searchLocation.distance(from: CLLocation(latitude: spot2.latitude, longitude: spot2.longitude))
                return distance1 < distance2
            }
        }
        
        // Otherwise, sort by distance from user's current location
        guard let userLocation = locationManager.location else {
            return chaiSpots
        }
        
        return chaiSpots.sorted { spot1, spot2 in
            let distance1 = userLocation.distance(from: CLLocation(latitude: spot1.latitude, longitude: spot1.longitude))
            let distance2 = userLocation.distance(from: CLLocation(latitude: spot2.latitude, longitude: spot2.longitude))
            return distance1 < distance2
        }
    }
    
    var body: some View {
        ZStack {
            if sortedChaiSpots.isEmpty {
                VStack {
                    Spacer()
                    if isGeocoding {
                        ProgressView("Finding locations...")
                            .font(DesignSystem.Typography.bodyLarge)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    } else {
                        Text("No chai spots found")
                            .font(DesignSystem.Typography.bodyLarge)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: DesignSystem.Spacing.md) {
                        ForEach(sortedChaiSpots) { spot in
                            ChaiSpotCard(
                                spot: spot, 
                                userLocation: searchLocation ?? locationManager.location
                            )
                        }
                    }
                    .padding(DesignSystem.Spacing.lg)
                    .padding(.bottom, 100) // Space for FAB
                }
            }
            
            // Floating Action Button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: {
                        // Add new chai spot
                    }) {
                        Image(systemName: "plus")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 56, height: 56)
                            .background(DesignSystem.Colors.primary)
                            .clipShape(Circle())
                            .shadow(
                                color: DesignSystem.Shadows.medium.color,
                                radius: DesignSystem.Shadows.medium.radius,
                                x: DesignSystem.Shadows.medium.x,
                                y: DesignSystem.Shadows.medium.y
                            )
                    }
                    .padding(DesignSystem.Spacing.lg)
                }
            }
        }
        .onChange(of: searchText) { newValue in
            // Debounce the geocoding to avoid state modification during view updates
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if searchText == newValue {
                    geocodeSearchLocation(newValue)
                }
            }
        }
        .onChange(of: chaiSpots) { _ in
            // Debounce the filtering to avoid state modification during view updates
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                filterSpotsByLocation()
            }
        }
        .onAppear {
            filterSpotsByLocation()
        }
    }
    
    private func geocodeSearchLocation(_ searchText: String) {
        guard !searchText.isEmpty else {
            searchLocation = nil
            filteredSpots = chaiSpots
            return
        }
        
        // Check if it looks like a zip code (5 digits)
        if searchText.count == 5, let _ = Int(searchText) {
            geocodeZipCode(searchText)
            return
        }
        
        // Check if it looks like a city name (contains letters and possibly spaces)
        if searchText.range(of: "^[A-Za-z\\s]+$", options: .regularExpression) != nil {
            geocodeCity(searchText)
            return
        }
        
        // For other searches, try general geocoding
        geocodeGeneral(searchText)
    }
    
    private func geocodeZipCode(_ zipCode: String) {
        isGeocoding = true
        let geocoder = CLGeocoder()
        
        geocoder.geocodeAddressString(zipCode) { placemarks, error in
            DispatchQueue.main.async {
                self.isGeocoding = false
                
                if let error = error {
                    print("Geocoding error for zip code \(zipCode): \(error.localizedDescription)")
                    return
                }
                
                if let location = placemarks?.first?.location {
                    self.searchLocation = location
                    print("Found location for zip code \(zipCode): \(location.coordinate)")
                    self.filterSpotsByLocation()
                }
            }
        }
    }
    
    private func geocodeCity(_ cityName: String) {
        isGeocoding = true
        let geocoder = CLGeocoder()
        
        geocoder.geocodeAddressString(cityName) { placemarks, error in
            DispatchQueue.main.async {
                self.isGeocoding = false
                
                if let error = error {
                    print("Geocoding error for city \(cityName): \(error.localizedDescription)")
                    return
                }
                
                if let location = placemarks?.first?.location {
                    self.searchLocation = location
                    print("Found location for city \(cityName): \(location.coordinate)")
                    self.filterSpotsByLocation()
                }
            }
        }
    }
    
    private func geocodeGeneral(_ searchText: String) {
        isGeocoding = true
        let geocoder = CLGeocoder()
        
        geocoder.geocodeAddressString(searchText) { placemarks, error in
            DispatchQueue.main.async {
                self.isGeocoding = false
                
                if let error = error {
                    print("Geocoding error for \(searchText): \(error.localizedDescription)")
                    return
                }
                
                if let location = placemarks?.first?.location {
                    self.searchLocation = location
                    print("Found location for \(searchText): \(location.coordinate)")
                    self.filterSpotsByLocation()
                }
            }
        }
    }
    
    private func filterSpotsByLocation() {
        guard let searchLocation = searchLocation else {
            filteredSpots = chaiSpots
            return
        }
        
        // Filter spots within 50 miles of the search location
        let searchRadius: Double = 50 * 1609.34 // 50 miles in meters
        
        filteredSpots = chaiSpots.filter { spot in
            let spotLocation = CLLocation(latitude: spot.latitude, longitude: spot.longitude)
            let distance = searchLocation.distance(from: spotLocation)
            return distance <= searchRadius
        }
        
        print("Filtered \(chaiSpots.count) spots to \(filteredSpots.count) spots within 50 miles of search location")
    }
}

// MARK: - Chai Spot Card
struct ChaiSpotCard: View {
    let spot: ChaiSpot
    let userLocation: CLLocation?
    @State private var ratings: [Rating] = []
    @State private var isLoadingRatings = false
    @State private var showingRatingSheet = false
    @State private var isAddingToList = false
    @State private var showingAddToListAlert = false
    @State private var addToListMessage = ""
    
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
    
    var calculatedAverageRating: Double {
        guard !ratings.isEmpty else { return 0.0 }
        let totalRating = ratings.reduce(0) { $0 + $1.value }
        return Double(totalRating) / Double(ratings.count)
    }
    
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
                
                // Rating
                if calculatedAverageRating > 0 {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(String(format: "%.1f", calculatedAverageRating))★")
                            .font(DesignSystem.Typography.bodyMedium)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, DesignSystem.Spacing.sm)
                            .padding(.vertical, DesignSystem.Spacing.xs)
                            .background(DesignSystem.Colors.ratingGreen)
                            .cornerRadius(DesignSystem.CornerRadius.small)
                        
                        Text("\(ratings.count) reviews")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                } else if isLoadingRatings {
                    ProgressView()
                        .scaleEffect(0.6)
                }
            }
            
            // Chai Types
            if !spot.chaiTypes.isEmpty {
                Text("Chai Types: \(spot.chaiTypes.joined(separator: ", "))")
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
            
            // Details
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "location.fill")
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.primary)
                    
                    Text(distanceString)
                        .font(DesignSystem.Typography.bodySmall)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                
                Spacer()
                
                // Action Buttons
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Button("Rank") {
                        showingRatingSheet = true
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    
                    Button(isAddingToList ? "Adding..." : "Add to List") {
                        addToMyList()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(isAddingToList)
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
        .onAppear {
            loadRatings()
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
    
    private func addToMyList() {
        guard let userId = Auth.auth().currentUser?.uid else {
            addToListMessage = "Please log in to save spots to your list"
            showingAddToListAlert = true
            return
        }
        
        isAddingToList = true
        let db = Firestore.firestore()
        
        print("🔄 Adding spot '\(spot.name)' (ID: \(spot.id)) to user \(userId)'s saved spots")
        
        // First check if the user document exists and has savedSpots field
        db.collection("users").document(userId).getDocument { snapshot, error in
            if let error = error {
                DispatchQueue.main.async {
                    self.isAddingToList = false
                    self.addToListMessage = "Failed to add to list: \(error.localizedDescription)"
                    self.showingAddToListAlert = true
                    print("❌ Error checking user document: \(error.localizedDescription)")
                }
                return
            }
            
            if let data = snapshot?.data(), let existingSavedSpots = data["savedSpots"] as? [String] {
                // User document exists and has savedSpots field
                print("📄 User has \(existingSavedSpots.count) existing saved spots")
                self.updateSavedSpots(userId: userId, spotId: self.spot.id, existingSpots: existingSavedSpots)
            } else {
                // User document exists but no savedSpots field, or document doesn't exist
                print("📄 User document exists but no savedSpots field, creating new array")
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
                print("ℹ️ Spot already in saved list")
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
                    print("❌ Error updating saved spots: \(error.localizedDescription)")
                } else {
                    self.addToListMessage = "✅ \(self.spot.name) added to your list!"
                    self.showingAddToListAlert = true
                    print("✅ Successfully added spot to saved list. Total saved spots: \(updatedSpots.count)")
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
                    print("❌ Error creating savedSpots field: \(error.localizedDescription)")
                } else {
                    self.addToListMessage = "✅ \(self.spot.name) added to your list!"
                    self.showingAddToListAlert = true
                    print("✅ Successfully created savedSpots field with first spot")
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
            .limit(to: 5)
            .getDocuments { snapshot, error in
                DispatchQueue.main.async {
                    self.isLoadingRatings = false
                    
                    if let error = error {
                        print("❌ Error loading ratings for card: \(error.localizedDescription)")
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
                            return nil
                        }
                        
                        let username = data["username"] as? String
                        let comment = data["comment"] as? String
                        let timestamp = data["timestamp"] as? Timestamp
                        let likes = data["likes"] as? Int
                        let dislikes = data["dislikes"] as? Int
                        
                        return Rating(
                            id: document.documentID,
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
}

// MARK: - Chai Spot Model
struct ChaiSpot: Identifiable, Equatable {
    let id: String
    let name: String
    let address: String
    let latitude: Double
    let longitude: Double
    let chaiTypes: [String]
    let averageRating: Double
    let ratingCount: Int
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    // Implement Equatable
    static func == (lhs: ChaiSpot, rhs: ChaiSpot) -> Bool {
        return lhs.id == rhs.id
    }
} 