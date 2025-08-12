import SwiftUI
import MapKit
import Firebase
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore

struct SearchView: View {
    @State private var isMapView = true
    @State private var searchText = ""
    @State private var chaiSpots: [ChaiSpot] = []
    @State private var isLoading = false
    @State private var filteredSpots: [ChaiSpot] = []
    @State private var searchLocation: CLLocation?
    @State private var isGeocoding = false
    @State private var selectedSpot: ChaiSpot?
    @State private var showingAddChaiSpot = false
    @State private var showingAddConfirmation = false
    @State private var addConfirmationMessage = ""
    @State private var isAddingSpot = false
    @StateObject private var locationManager = LocationManager()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                headerSection
                contentSection
            }
            .background(DesignSystem.Colors.background)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .navigationBarHidden(true)
            .sheet(isPresented: $showingAddChaiSpot) {
                AddChaiFinderForm(
                    coordinate: locationManager.location?.coordinate,
                    onSubmit: { name, address, rating, comments, chaiTypes, coordinate, creaminessRating, chaiStrengthRating, flavorNotes in
                        // Convert flavorNotes array to a comma-separated string
                        let flavorNotesString = flavorNotes.joined(separator: ", ")
                        handleAddChaiSpot(name: name, address: address, rating: rating, comments: comments, chaiTypes: chaiTypes, coordinate: coordinate, creaminessRating: creaminessRating, chaiStrengthRating: chaiStrengthRating, flavorNotes: flavorNotesString)
                    }
                )
            }
            .onChange(of: showingAddChaiSpot) { newValue in
                if !newValue {
                    isAddingSpot = false
                }
            }
            .onAppear {
                loadAllChaiSpots()
            }
        }
        .navigationViewStyle(.stack)
        .alert("Add Confirmation", isPresented: $showingAddConfirmation) {
            Button("OK", role: .cancel) {
                if showingAddConfirmation {
                    showingAddConfirmation = false
                    addConfirmationMessage = ""
                }
            }
        } message: {
            Text(addConfirmationMessage)
        }
    }
    
    // MARK: - View Components
    
    private var headerSection: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            breadcrumbTitle
            brandTitle
            viewToggle
            searchBar
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.background)
        .iPadOptimized()
    }
    
    private var breadcrumbTitle: some View {
        Text("Search")
            .font(DesignSystem.Typography.caption)
            .foregroundColor(DesignSystem.Colors.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var brandTitle: some View {
        Text("chai finder")
            .font(DesignSystem.Typography.titleLarge)
            .fontWeight(.bold)
            .foregroundColor(DesignSystem.Colors.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var viewToggle: some View {
        HStack(spacing: 0) {
            Button(action: { isMapView = true }) {
                let mapViewTextColor = isMapView ? .white : DesignSystem.Colors.textSecondary
                let mapViewBackground = isMapView ? DesignSystem.Colors.primary : DesignSystem.Colors.secondary
                
                Text("Map View")
                    .font(DesignSystem.Typography.bodyMedium)
                    .fontWeight(.medium)
                    .foregroundColor(mapViewTextColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignSystem.Spacing.md)
                    .background(mapViewBackground)
            }
            
            Button(action: { isMapView = false }) {
                let listViewTextColor = !isMapView ? .white : DesignSystem.Colors.textSecondary
                let listViewBackground = !isMapView ? DesignSystem.Colors.primary : DesignSystem.Colors.secondary
                
                Text("List View")
                    .font(DesignSystem.Typography.bodyMedium)
                    .fontWeight(.medium)
                    .foregroundColor(listViewTextColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignSystem.Spacing.md)
                    .background(listViewBackground)
            }
        }
        .cornerRadius(DesignSystem.CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                .stroke(DesignSystem.Colors.border, lineWidth: 1)
        )
    }
    
    private var searchBar: some View {
        HStack {
            let searchIconSize = UIDevice.current.userInterfaceIdiom == .pad ? CGFloat(20) : CGFloat(16)
            
            Image(systemName: "magnifyingglass")
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .font(.system(size: searchIconSize))
            
            TextField("Search for a chai spot, type, etc.", text: $searchText)
                .font(DesignSystem.Typography.bodyMedium)
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .onChange(of: searchText) { newValue in
                    if !newValue.isEmpty {
                        searchChaiSpots()
                    } else {
                        loadAllChaiSpots()
                    }
                }
            
            if !searchText.isEmpty {
                Button(action: { 
                    DispatchQueue.main.async {
                        searchText = ""
                        loadAllChaiSpots()
                    }
                }) {
                    let clearIconSize = UIDevice.current.userInterfaceIdiom == .pad ? CGFloat(20) : CGFloat(16)
                    
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .font(.system(size: clearIconSize))
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
    
    private var contentSection: some View {
        VStack(spacing: 0) {
            if isMapView {
                MapSearchView(searchText: $searchText, chaiSpots: $chaiSpots, searchLocation: $searchLocation, locationManager: locationManager, onAddChaiSpot: {
                    showingAddChaiSpot = true
                })
            } else {
                ListSearchView(searchText: $searchText, chaiSpots: $chaiSpots, locationManager: locationManager, onAddChaiSpot: {
                    showingAddChaiSpot = true
                })
            }
            Spacer(minLength: 0)
        }
    }
    
    private func searchChaiSpots() {
        guard !searchText.isEmpty else {
            loadAllChaiSpots()
            return
        }
        
        print("🔍 Searching for: '\(searchText)'")
        
        // Check if it's a location-based search (zip code, city, or address)
        let isZipCode = searchText.count == 5 && Int(searchText) != nil
        let isCityName = searchText.range(of: "^[A-Za-z\\s]+$", options: .regularExpression) != nil
        let containsStreetTerms = searchText.lowercased().contains("street") ||
                                 searchText.lowercased().contains("avenue") ||
                                 searchText.lowercased().contains("road") ||
                                 searchText.lowercased().contains("drive") ||
                                 searchText.lowercased().contains("lane") ||
                                 searchText.lowercased().contains("blvd") ||
                                 searchText.lowercased().contains("st") ||
                                 searchText.lowercased().contains("ave") ||
                                 searchText.lowercased().contains("rd")
        
        let isLocationSearch = isZipCode || isCityName || containsStreetTerms
        
        if isLocationSearch {
            print("📍 Detected location search, geocoding and centering map...")
            // For location searches, geocode the location and center the map
            geocodeSearchLocation(searchText)
            // Also load all spots for the list view
            loadAllChaiSpots()
        } else {
            print("🔍 Detected content search, searching database...")
            // For content searches (names, reviews, etc.), search the database
            searchByNameAddressAndReviews()
        }
    }
    
    private func searchByNameAddressAndReviews() {
        isLoading = true
        let db = Firestore.firestore()
        
        print("🔍 Searching database for: '\(searchText)'")
        
        // Search both name and address simultaneously for better results
        let group = DispatchGroup()
        var nameResults: [ChaiSpot] = []
        var addressResults: [ChaiSpot] = []
        
        // Search by name
        group.enter()
        db.collection("chaiFinder")
            .whereField("name", isGreaterThanOrEqualTo: searchText)
            .whereField("name", isLessThan: searchText + "\u{f8ff}")
            .getDocuments { snapshot, error in
                defer { group.leave() }
                
                if let error = error {
                    print("❌ Error searching by name: \(error.localizedDescription)")
                } else if let documents = snapshot?.documents {
                    nameResults = self.processSearchResults(documents)
                    print("✅ Found \(nameResults.count) results by name")
                }
            }
        
        // Search by address
        group.enter()
        db.collection("chaiFinder")
            .whereField("address", isGreaterThanOrEqualTo: searchText)
            .whereField("address", isLessThan: searchText + "\u{f8ff}")
            .getDocuments { snapshot, error in
                defer { group.leave() }
                
                if let error = error {
                    print("❌ Error searching by address: \(error.localizedDescription)")
                } else if let documents = snapshot?.documents {
                    addressResults = self.processSearchResults(documents)
                    print("✅ Found \(addressResults.count) results by address")
                }
            }
        
        // Combine results when both searches complete
        group.notify(queue: .main) {
            // Combine results, removing duplicates by ID
            var combinedResults: [ChaiSpot] = []
            var seenIds: Set<String> = []
            
            // Add name results first (prioritize name matches)
            for spot in nameResults {
                if !seenIds.contains(spot.id) {
                    combinedResults.append(spot)
                    seenIds.insert(spot.id)
                }
            }
            
            // Add address results
            for spot in addressResults {
                if !seenIds.contains(spot.id) {
                    combinedResults.append(spot)
                    seenIds.insert(spot.id)
                }
            }
            
            if !combinedResults.isEmpty {
                print("✅ Combined search results: \(combinedResults.count) unique spots")
                self.chaiSpots = combinedResults
            } else {
                // If no results from name/address search, try review content search
                print("🔍 No name/address results, trying review content search...")
                self.searchByReviewContent()
                return
            }
            
            self.isLoading = false
        }
    }
    
    private func searchByReviewContent() {
        let db = Firestore.firestore()
        
        print("🔍 Searching by review content: '\(searchText)'")
        
        // For review content search, we need to search in the ratings collection
        // This is more complex as we need to find ratings that contain the search text
        // and then get the corresponding chai spots
        
        db.collection("ratings")
            .whereField("comments", isGreaterThanOrEqualTo: searchText)
            .whereField("comments", isLessThan: searchText + "\u{f8ff}")
            .getDocuments { snapshot, error in
                DispatchQueue.main.async {
                    self.isLoading = false
                    
                    if let error = error {
                        print("❌ Error searching by review content: \(error.localizedDescription)")
                        self.chaiSpots = []
                        return
                    }
                    
                    guard let documents = snapshot?.documents else {
                        print("❌ No review content found for: '\(self.searchText)'")
                        self.chaiSpots = []
                        return
                    }
                    
                    // Extract unique spot IDs from the ratings
                    let spotIds = Set(documents.compactMap { doc in
                        doc.data()["spotId"] as? String
                    })
                    
                    print("📝 Found \(spotIds.count) unique spots with matching review content")
                    
                    if spotIds.isEmpty {
                        self.chaiSpots = []
                        return
                    }
                    
                    // Now fetch the actual chai spots for these IDs
                    self.fetchChaiSpotsByIds(Array(spotIds))
                }
            }
    }
    
    private func fetchChaiSpotsByIds(_ spotIds: [String]) {
        let db = Firestore.firestore()
        
        print("🔄 Fetching \(spotIds.count) chai spots by IDs...")
        
        var fetchedSpots: [ChaiSpot] = []
        let group = DispatchGroup()
        
        for spotId in spotIds {
            group.enter()
            
            db.collection("chaiFinder").document(spotId).getDocument { snapshot, error in
                defer { group.leave() }
                
                if let error = error {
                    print("❌ Error fetching spot \(spotId): \(error.localizedDescription)")
                    return
                }
                
                guard let document = snapshot, document.exists,
                      let data = document.data() else {
                    print("⚠️ Spot \(spotId) not found or has no data")
                    return
                }
                
                guard let name = data["name"] as? String,
                      let latitude = data["latitude"] as? Double,
                      let longitude = data["longitude"] as? Double,
                      let address = data["address"] as? String else {
                    print("⚠️ Spot \(spotId) missing required fields")
                    return
                }
                
                let chaiTypes = data["chaiTypes"] as? [String] ?? []
                let averageRating = data["averageRating"] as? Double ?? 0.0
                let ratingCount = data["ratingCount"] as? Int ?? 0
                
                let spot = ChaiSpot(
                    id: document.documentID,
                    name: name,
                    address: address,
                    latitude: latitude,
                    longitude: longitude,
                    chaiTypes: chaiTypes,
                    averageRating: averageRating,
                    ratingCount: ratingCount
                )
                
                fetchedSpots.append(spot)
            }
        }
        
        group.notify(queue: .main) {
            print("✅ Fetched \(fetchedSpots.count) spots from review content search")
            self.chaiSpots = fetchedSpots
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
                
                // Log all document IDs for debugging
                let documentIds = documents.map { $0.documentID }
                print("📋 Document IDs: \(documentIds)")
                
                // Log the first few documents' data for debugging
                for (index, doc) in documents.prefix(3).enumerated() {
                    let data = doc.data()
                    print("📝 Document \(index + 1) data: \(data)")
                }
                
                self.chaiSpots = self.processSearchResults(documents)
                print("✅ Processed \(self.chaiSpots.count) chai spots")
                
                // Log the names of all processed spots
                let spotNames = self.chaiSpots.map { $0.name }
                print("🏪 Spot names: \(spotNames)")
            }
        }
    }
    
    private func processSearchResults(_ documents: [QueryDocumentSnapshot]) -> [ChaiSpot] {
        print("🔄 Processing \(documents.count) documents...")
        
        let processedSpots: [ChaiSpot] = documents.compactMap { document in
            let data = document.data()
            print("🔍 Processing document \(document.documentID) with data: \(data)")
            
            guard let name = data["name"] as? String,
                  let latitude = data["latitude"] as? Double,
                  let longitude = data["longitude"] as? Double,
                  let address = data["address"] as? String else {
                print("⚠️ Skipping document \(document.documentID) - missing required fields")
                print("   name: \(data["name"] ?? "nil")")
                print("   latitude: \(data["latitude"] ?? "nil")")
                print("   longitude: \(data["longitude"] ?? "nil")")
                print("   address: \(data["address"] ?? "nil")")
                return nil
            }
            
            let chaiTypes = data["chaiTypes"] as? [String] ?? []
            let averageRating = data["averageRating"] as? Double ?? 0.0
            let ratingCount = data["ratingCount"] as? Int ?? 0
            
            let spot = ChaiSpot(
                id: document.documentID,
                name: name,
                address: address,
                latitude: latitude,
                longitude: longitude,
                chaiTypes: chaiTypes,
                averageRating: averageRating,
                ratingCount: ratingCount
            )
            
            print("✅ Processed spot: \(name) (ID: \(document.documentID))")
            return spot
        }
        
        print("📊 Final processed spots count: \(processedSpots.count)")
        return processedSpots
    }
    
    // MARK: - Geocoding Functions
    private func geocodeSearchLocation(_ searchText: String) {
        guard !searchText.isEmpty else {
            searchLocation = nil
            return
        }
        
        print("🗺️ Geocoding search location: '\(searchText)'")
        
        // Check if it looks like a zip code (5 digits)
        let isZipCode = searchText.count == 5
        let canConvertToInt = Int(searchText) != nil
        
        if isZipCode && canConvertToInt {
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
                    print("❌ Geocoding error for zip code \(zipCode): \(error.localizedDescription)")
                    return
                }
                
                if let location = placemarks?.first?.location {
                    self.searchLocation = location
                    print("✅ Found location for zip code \(zipCode): \(location.coordinate)")
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
                    print("❌ Geocoding error for city \(cityName): \(error.localizedDescription)")
                    return
                }
                
                if let location = placemarks?.first?.location {
                    self.searchLocation = location
                    print("✅ Found location for city \(cityName): \(location.coordinate)")
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
                    print("❌ Geocoding error for \(searchText): \(error.localizedDescription)")
                    return
                }
                
                if let location = placemarks?.first?.location {
                    self.searchLocation = location
                    print("✅ Found location for \(searchText): \(location.coordinate)")
                }
            }
        }
    }
    
    // MARK: - Add Chai Spot Handler
    private func handleAddChaiSpot(name: String, address: String, rating: Int, comments: String, chaiTypes: [String], coordinate: CLLocationCoordinate2D, creaminessRating: Int, chaiStrengthRating: Int, flavorNotes: String) {
        let db = Firestore.firestore()
        
        // Check if Firebase is initialized before accessing Auth
        if FirebaseApp.app() == nil {
            print("⚠️ Firebase not initialized")
            DispatchQueue.main.async {
                self.addConfirmationMessage = "Please sign in to add locations"
                self.showingAddConfirmation = true
            }
            return
        }
        
        // Check if user is authenticated
        guard let currentUser = Auth.auth().currentUser else {
            print("❌ User not authenticated")
            DispatchQueue.main.async {
                self.addConfirmationMessage = "Please sign in to add locations"
                self.showingAddConfirmation = true
            }
            return
        }
        
        // Check for duplicate spots (same name and address)
        let normalizedName = name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedAddress = address.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check if a spot with the same name and address already exists
        db.collection("chaiFinder")
            .whereField("name", isEqualTo: name)
            .whereField("address", isEqualTo: address)
            .getDocuments { snapshot, error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("❌ Error checking for duplicates: \(error.localizedDescription)")
                        self.addConfirmationMessage = "Error checking for duplicates. Please try again."
                        self.showingAddConfirmation = true
                        return
                    }
                    
                    if let documents = snapshot?.documents, !documents.isEmpty {
                        print("⚠️ Duplicate spot found: \(name) at \(address)")
                        self.addConfirmationMessage = "A spot with this name and address already exists!"
                        self.showingAddConfirmation = true
                        return
                    }
                    
                    // No duplicates found, proceed with adding the spot
                    self.addSpotToDatabase(name: name, address: address, rating: rating, comments: comments, chaiTypes: chaiTypes, coordinate: coordinate, creaminessRating: creaminessRating, chaiStrengthRating: chaiStrengthRating, flavorNotes: flavorNotes)
                }
            }
    }
    
    private func addSpotToDatabase(name: String, address: String, rating: Int, comments: String, chaiTypes: [String], coordinate: CLLocationCoordinate2D, creaminessRating: Int, chaiStrengthRating: Int, flavorNotes: String) {
        let db = Firestore.firestore()
        
        let newSpotData: [String: Any] = [
            "name": name,
            "address": address,
            "latitude": coordinate.latitude,
            "longitude": coordinate.longitude,
            "chaiTypes": chaiTypes,
            "averageRating": Double(rating),
            "ratingCount": 1,
            "createdAt": FieldValue.serverTimestamp()
        ]
        
        print("🔄 Adding new chai spot to database: \(name)")
        print("📍 Location: \(coordinate.latitude), \(coordinate.longitude)")
        
        isAddingSpot = true
        
        let spotRef = db.collection("chaiFinder").document()
        spotRef.setData(newSpotData) { error in
            DispatchQueue.main.async {
                self.isAddingSpot = false
                
                if let error = error {
                    print("❌ Failed to add chai spot: \(error.localizedDescription)")
                    
                    if error.localizedDescription.contains("permission") || error.localizedDescription.contains("Permission denied") {
                        self.addConfirmationMessage = "Unable to add location due to permissions. Please contact support."
                    } else {
                        self.addConfirmationMessage = "Failed to add location: \(error.localizedDescription)"
                    }
                    self.showingAddConfirmation = true
                } else {
                    print("✅ Successfully added chai spot to database")
                    
                    // Create a new ChaiSpot object with the data
                    let newSpot = ChaiSpot(
                        id: spotRef.documentID,
                        name: name,
                        address: address,
                        latitude: coordinate.latitude,
                        longitude: coordinate.longitude,
                        chaiTypes: chaiTypes,
                        averageRating: Double(rating),
                        ratingCount: 1
                    )
                    
                    // Add to the current list immediately for better UX
                    self.chaiSpots.insert(newSpot, at: 0)
                    
                    // Clear any active search to show all spots including the new one
                    self.searchText = ""
                    
                    // Show success confirmation
                    self.addConfirmationMessage = "✅ Successfully added '\(name)' to your chai spots!"
                    self.showingAddConfirmation = true
                    
                    // Close the add form
                    self.showingAddChaiSpot = false
                    
                    // Also create the user's initial rating so it shows in feeds/list
                    if let user = Auth.auth().currentUser {
                        // Fetch display name from users collection if available
                        db.collection("users").document(user.uid).getDocument { doc, _ in
                            var username = user.email ?? user.uid
                            if let data = doc?.data(), let displayName = data["displayName"] as? String, !displayName.isEmpty {
                                username = displayName
                            }
                            var ratingDict: [String: Any] = [
                                "spotId": spotRef.documentID,
                                "userId": user.uid,
                                "username": username,
                                "value": rating,
                                "comment": comments,
                                "timestamp": FieldValue.serverTimestamp(),
                                "creaminessRating": creaminessRating,
                                "chaiStrengthRating": chaiStrengthRating,
                                "flavorNotes": flavorNotes
                            ]
                            if let firstType = chaiTypes.first { ratingDict["chaiType"] = firstType }
                            db.collection("ratings").addDocument(data: ratingDict)
                        }
                    }

                    // Reload all spots after a short delay to ensure consistency
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: DispatchWorkItem {
                        self.loadAllChaiSpots()
                    })
                }
            }
        }
    }
} 

// MARK: - Map Search View
struct MapSearchView: View {
    @Binding var searchText: String
    @Binding var chaiSpots: [ChaiSpot]
    @Binding var searchLocation: CLLocation?
    @ObservedObject var locationManager: LocationManager
    let onAddChaiSpot: () -> Void
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194), // Default to San Francisco
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    @State private var selectedSpot: ChaiSpot?
    @State private var showingSpotDetail = false
    @State private var isGeocoding = false
    @State private var showingAddChaiSpot = false
    
    var body: some View {
        ZStack {
            Map(coordinateRegion: $region, annotationItems: chaiSpots) { spot in
                MapAnnotation(coordinate: spot.coordinate) {
                    Button(action: {
                        // Present sheet by setting selectedSpot; avoid additional boolean to prevent state-change-during-update warnings
                        selectedSpot = spot
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
                    Button(action: onAddChaiSpot) {
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
        .onChange(of: searchLocation) { location in
            // Center map on the searched location
            if let location = location {
                print("🗺️ Centering map on searched location: \(location.coordinate)")
                withAnimation(.easeInOut(duration: 0.5)) {
                    region = MKCoordinateRegion(
                        center: location.coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                    )
                }
            }
        }
        .sheet(item: $selectedSpot) { spot in
            ChaiSpotDetailSheet(spot: spot, userLocation: locationManager.location)
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
    let onAddChaiSpot: () -> Void
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
                        onAddChaiSpot()
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
        .onChange(of: chaiSpots) { _ in
            // Debounce the filtering to avoid state modification during view updates
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: DispatchWorkItem {
                filterSpotsByLocation()
            })
        }
        .onAppear {
            filterSpotsByLocation()
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
    @State private var friendRatings: [Rating] = []
    @State private var isLoadingRatings = false
    @State private var isLoadingFriendRatings = false
    @State private var showingRatingSheet = false
    @State private var isAddingToList = false
    @State private var showingAddToListAlert = false
    @State private var addToListMessage = ""
    @State private var isSpotSaved = false
    @State private var showingDetailSheet = false
    
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
        if !ratings.isEmpty {
            let totalRating = ratings.reduce(0) { $0 + $1.value }
            return Double(totalRating) / Double(ratings.count)
        } else {
            return spot.averageRating
        }
    }
    
    var displayRatingCount: Int {
        return !ratings.isEmpty ? ratings.count : spot.ratingCount
    }
    
    var calculatedFriendAverageRating: Double {
        guard !friendRatings.isEmpty else { return 0.0 }
        let totalRating = friendRatings.reduce(0) { $0 + $1.value }
        return Double(totalRating) / Double(friendRatings.count)
    }
    
    var body: some View {
        ZStack {
            // Card content
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) { // Reduced from md to sm
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
                    
                    // Ratings Section
                    VStack(alignment: .trailing, spacing: 4) {
                        // Community Rating
                        HStack(spacing: 4) {
                            Text("Community:")
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                            
                            if calculatedAverageRating > 0 {
                                Text("\(String(format: "%.1f", calculatedAverageRating))★")
                                    .font(DesignSystem.Typography.bodyMedium)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(DesignSystem.Colors.ratingGreen)
                                    .cornerRadius(DesignSystem.CornerRadius.small)
                                
                                Text("(\(displayRatingCount))")
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                            } else {
                                Text("No ratings")
                                    .font(DesignSystem.Typography.bodySmall)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(DesignSystem.Colors.secondary.opacity(0.3))
                                    .cornerRadius(DesignSystem.CornerRadius.small)
                            }
                        }
                        
                        // Friends Rating
                        HStack(spacing: 4) {
                            Text("Friends:")
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                            
                            if calculatedFriendAverageRating > 0 {
                                Text("\(String(format: "%.1f", calculatedFriendAverageRating))★")
                                    .font(DesignSystem.Typography.bodyMedium)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(DesignSystem.Colors.primary)
                                    .cornerRadius(DesignSystem.CornerRadius.small)
                                
                                Text("(\(friendRatings.count))")
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                            } else {
                                Text("No ratings")
                                    .font(DesignSystem.Typography.bodySmall)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(DesignSystem.Colors.secondary.opacity(0.3))
                                    .cornerRadius(DesignSystem.CornerRadius.small)
                            }
                        }
                        
                        if isLoadingRatings || isLoadingFriendRatings {
                            ProgressView()
                                .scaleEffect(0.6)
                        }
                    }
                }
                
                // Chai Types
                if !spot.chaiTypes.isEmpty {
                    Text("Chai Types: \(spot.chaiTypes.joined(separator: ", "))")
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                
                // Rating Details - Show from most recent rating if available
                if let mostRecentRating = ratings.first {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text("Recent Rating Details")
                            .font(DesignSystem.Typography.bodySmall)
                            .fontWeight(.semibold)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        
                        HStack(spacing: DesignSystem.Spacing.md) {
                            // Creaminess Rating
                            if let creaminessRating = mostRecentRating.creaminessRating {
                                HStack(spacing: 2) {
                                    Image(systemName: "drop.fill")
                                        .foregroundColor(DesignSystem.Colors.creaminessRating)
                                        .font(.caption)
                                    Text("\(creaminessRating)/5")
                                        .font(DesignSystem.Typography.caption)
                                        .foregroundColor(DesignSystem.Colors.textSecondary)
                                }
                            } else {
                                HStack(spacing: 2) {
                                    Image(systemName: "drop")
                                        .foregroundColor(DesignSystem.Colors.border)
                                        .font(.caption)
                                    Text("NR")
                                        .font(DesignSystem.Typography.caption)
                                        .foregroundColor(DesignSystem.Colors.textSecondary)
                                        .italic()
                                }
                            }
                            
                            // Chai Strength Rating
                            if let chaiStrengthRating = mostRecentRating.chaiStrengthRating {
                                HStack(spacing: 2) {
                                    Image(systemName: "leaf.fill")
                                        .foregroundColor(DesignSystem.Colors.chaiStrengthRating)
                                        .font(.caption)
                                    Text("\(chaiStrengthRating)/5")
                                        .font(DesignSystem.Typography.caption)
                                        .foregroundColor(DesignSystem.Colors.textSecondary)
                                }
                            } else {
                                HStack(spacing: 2) {
                                    Image(systemName: "leaf")
                                        .foregroundColor(DesignSystem.Colors.border)
                                        .font(.caption)
                                    Text("NR")
                                        .font(DesignSystem.Typography.caption)
                                        .foregroundColor(DesignSystem.Colors.textSecondary)
                                        .italic()
                                }
                            }
                        }
                        
                        // Flavor Notes
                        if let flavorNotes = mostRecentRating.flavorNotes, !flavorNotes.isEmpty {
                            HStack(spacing: DesignSystem.Spacing.xs) {
                                Text("Flavors:")
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                                
                                LazyHGrid(rows: Array(repeating: GridItem(.flexible()), count: 1), spacing: DesignSystem.Spacing.xs) {
                                    ForEach(flavorNotes, id: \.self) { note in
                                        Text(note)
                                            .font(DesignSystem.Typography.caption)
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 2)
                                            .background(DesignSystem.Colors.flavorNotesRating)
                                            .cornerRadius(DesignSystem.CornerRadius.small)
                                    }
                                }
                            }
                        } else {
                            HStack(spacing: DesignSystem.Spacing.xs) {
                                Text("Flavors:")
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                                
                                Text("NR")
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                                    .italic()
                            }
                        }
                    }
                    .padding(.top, DesignSystem.Spacing.xs)
                } else {
                    // No ratings available
                    Text("No ratings available")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .italic()
                        .padding(.top, DesignSystem.Spacing.xs)
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
                    HStack(spacing: DesignSystem.Spacing.xs) { // Reduced spacing from sm to xs
                        Button("Rate") {
                            showingRatingSheet = true
                        }
                        .buttonStyle(SecondaryButtonStyle())
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 44) // Minimum height instead of fixed height
                        .allowsHitTesting(true)
                        
                        Button(isAddingToList ? "Adding..." : (isSpotSaved ? "Saved" : "Save")) {
                            if !isSpotSaved {
                                addToMyList()
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(isAddingToList || isSpotSaved)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 44) // Minimum height instead of fixed height
                        .allowsHitTesting(true)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(DesignSystem.Spacing.md) // Reduced from lg to md for more content space
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.medium)
        .shadow(
            color: DesignSystem.Shadows.small.color,
            radius: DesignSystem.Shadows.small.radius,
            x: DesignSystem.Shadows.small.x,
            y: DesignSystem.Shadows.small.y
        )
        .contentShape(Rectangle())
        .onTapGesture {
            showingDetailSheet = true
        }
        .onAppear {
            loadRatings()
            checkIfSpotIsSaved()
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
        .sheet(isPresented: $showingDetailSheet) {
            ChaiSpotDetailSheet(spot: spot, userLocation: userLocation)
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
                self.isSpotSaved = true // Set the state to true
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
                    self.isSpotSaved = true // Set the state to true
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
                    self.isSpotSaved = true // Set the state to true
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
                        
                        // Debug logging for rating fields
                        print("🔍 Loading rating for spot \(spotId):")
                        print("   - creaminessRating: \(String(describing: data["creaminessRating"]))")
                        print("   - chaiStrengthRating: \(String(describing: data["chaiStrengthRating"]))")
                        print("   - flavorNotes: \(String(describing: data["flavorNotes"]))")
                        
                        return Rating(
                            spotId: spotId,
                            userId: userId,
                            username: username,
                            value: value,
                            comment: comment,
                            timestamp: timestamp?.dateValue(),
                            likes: likes,
                            dislikes: dislikes,
                            creaminessRating: data["creaminessRating"] as? Int,
                            chaiStrengthRating: data["chaiStrengthRating"] as? Int,
                            flavorNotes: data["flavorNotes"] as? [String]
                        )
                    }
                    
                    print("✅ Loaded \(self.ratings.count) ratings for spot \(self.spot.name)")
                    if let firstRating = self.ratings.first {
                        print("   - First rating has creaminess: \(String(describing: firstRating.creaminessRating))")
                        print("   - First rating has strength: \(String(describing: firstRating.chaiStrengthRating))")
                        print("   - First rating has flavors: \(String(describing: firstRating.flavorNotes))")
                    }
                }
            }
        
        // Also load friend ratings
        loadFriendRatings()
    }
    
    private func loadFriendRatings() {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            return
        }
        
        isLoadingFriendRatings = true
        let db = Firestore.firestore()
        
        // First get the current user's friends
        db.collection("users").document(currentUserId).getDocument { snapshot, error in
            if let error = error {
                print("❌ Error loading user friends: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.isLoadingFriendRatings = false
                }
                return
            }
            
            guard let data = snapshot?.data(),
                  let friends = data["friends"] as? [String],
                  !friends.isEmpty else {
                DispatchQueue.main.async {
                    self.isLoadingFriendRatings = false
                }
                return
            }
            
            // Now get ratings from friends for this spot
            db.collection("ratings")
                .whereField("spotId", isEqualTo: self.spot.id)
                .whereField("userId", in: friends)
                .getDocuments { snapshot, error in
                    DispatchQueue.main.async {
                        self.isLoadingFriendRatings = false
                        
                        if let error = error {
                            print("❌ Error loading friend ratings: \(error.localizedDescription)")
                            return
                        }
                        
                        guard let documents = snapshot?.documents else {
                            return
                        }
                        
                        self.friendRatings = documents.compactMap { document -> Rating? in
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
                                spotId: spotId,
                                userId: userId,
                                username: username,
                                value: value,
                                comment: comment,
                                timestamp: timestamp?.dateValue(),
                                likes: likes,
                                dislikes: dislikes,
                                creaminessRating: data["creaminessRating"] as? Int,
                                chaiStrengthRating: data["chaiStrengthRating"] as? Int,
                                flavorNotes: data["flavorNotes"] as? [String]
                            )
                        }
                        
                        print("✅ Loaded \(self.friendRatings.count) friend ratings for \(self.spot.name)")
                    }
                }
        }
    }
    
    private func checkIfSpotIsSaved() {
        guard let userId = Auth.auth().currentUser?.uid else {
            DispatchQueue.main.async {
                self.isSpotSaved = false // Not logged in
            }
            return
        }
        
        let db = Firestore.firestore()
        
        db.collection("users").document(userId).getDocument { snapshot, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Error checking if spot is saved: \(error.localizedDescription)")
                    self.isSpotSaved = false
                    return
                }
                
                if let data = snapshot?.data(), let savedSpots = data["savedSpots"] as? [String] {
                    self.isSpotSaved = savedSpots.contains(self.spot.id)
                    print("✅ Spot \(self.spot.name) (ID: \(self.spot.id)) is saved: \(self.isSpotSaved)")
                } else {
                    self.isSpotSaved = false
                    print("✅ Spot \(self.spot.name) (ID: \(self.spot.id)) is NOT saved.")
                }
            }
        }
    }
} 