import SwiftUI
import MapKit
import CoreLocation
import Firebase
import FirebaseFirestore
import FirebaseAuth

struct PersonalizedMapView: View {
    @StateObject private var vm = PersonalizedMapViewModel()
    @EnvironmentObject var session: SessionStore
    @FocusState private var isSearchFocused: Bool
    // Map region - dynamic based on user location or spots
    @State private var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    
    // Location manager for distance sorting
    @State private var locationManager = CLLocationManager()
    @State private var locationDelegate: LocationManagerDelegate?
    
    // Spot detail navigation
    @State private var selectedSpot: ChaiSpot?
    @State private var showingSpotDetail = false
    @State private var cameFromListView = false
    
    // Map interaction state
    @State private var isUserInteractingWithMap = false
    
    // Map view reference for programmatic updates
    @State private var mapViewRef: MKMapView?
    
    // Add location button state
    @State private var showingAddForm = false
    @State private var selectedCoordinate: CLLocationCoordinate2D?
    
    // Store current map region to prevent resetting
    @State private var currentMapRegion: MKCoordinateRegion?
    
    // Personalization explanation alert state
    @State private var showingPersonalizationAlert = false
    @State private var selectedSpotForExplanation: ChaiSpot?
    
    // Computed property to get the map region, with fallback to default
    private var effectiveMapRegion: MKCoordinateRegion {
        if let storedRegion = getStoredMapRegion() {
            return storedRegion
        } else if let currentRegion = currentMapRegion {
            return currentRegion
        } else {
            return mapRegion
        }
    }
    
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
                    mapViewContent
                }
            }
            .background(DesignSystem.Colors.background)
            .navigationBarHidden(true) // Hide navigation bar since we have custom header
            .gesture(
                DragGesture()
                    .onChanged { _ in
                        // Dismiss keyboard when user starts dragging
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
            )
            .onAppear {
                print("🎯 PersonalizedMapView appeared")
                setupLocationManager()
            }
            .onDisappear {
                // Store the current map region when the view disappears
                storeCurrentMapRegion()
            }
            .onChange(of: vm.isShowingList) { isShowingList in
                // Store the current map region when switching views
                if !isShowingList {
                    // We're switching to map view, store the current region
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        storeCurrentMapRegion()
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .tasteSetupCompleted)) { _ in
                Task {
                    await vm.refreshPersonalization()
                    // Don't auto-center - let user control the map
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .ratingUpdated)) { _ in
                Task {
                    await vm.refreshPersonalization()
                    // Don't auto-center - let user control the map
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .spotsUpdated)) { _ in
                print("🔄 Received spotsUpdated notification - triggering map refresh")
                vm.mapUpdateTrigger = UUID()
                
                // Update map region to include new spots
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    updateMapRegion()
                }
            }
            .task {
                print("🚀 PersonalizedMapView task started")
                await vm.loadAllSpots()
                print("🚀 PersonalizedMapView task completed")
                
                // Update map region based on loaded spots or user location
                updateMapRegion()
                
                // Don't auto-center on load - let user control the map
                // Only center if this is the very first time the view appears
            }
            .sheet(isPresented: $showingSpotDetail) {
                if let spot = selectedSpot {
                    ChaiSpotDetailSheet(spot: spot, userLocation: locationManager.location)
                        .onDisappear {
                            // If user came from list view, return to list view
                            if cameFromListView {
                                print("🔄 Returning to list view after dismissing spot details")
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    vm.isShowingList = true
                                }
                                cameFromListView = false
                            } else {
                                print("🔄 Staying in map view after dismissing spot details")
                            }
                        }
                }
            }
            .sheet(isPresented: $showingAddForm) {
                if let coordinate = selectedCoordinate {
                    UnifiedChaiForm(
                        isAddingNewSpot: true,
                        existingSpot: nil,
                        coordinate: coordinate,
                        onComplete: {
                            // Dismiss the form and clear the selected coordinate
                            showingAddForm = false
                            selectedCoordinate = nil
                        }
                    )
                }
            }
            .alert("Understanding Your Match Score", isPresented: $showingPersonalizationAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("This score shows how well this chai spot matches your personal preferences on a 1-5 scale. It's calculated from your taste preferences, ratings of similar spots, friend recommendations, and community ratings. 4-5 stars = great match, 3-4 stars = good match, 1-2 stars = low match.")
            }
        }
        .navigationViewStyle(.stack)
        .searchBarKeyboardDismissible()
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: DesignSystem.Spacing.sm) { // Reduced spacing for more compact design
            HStack {
                // Brand title - consistent with other pages
                Text("chai finder")
                    .font(DesignSystem.Typography.titleLarge)
                    .fontWeight(.bold)
                    .foregroundColor(DesignSystem.Colors.primary)
                    .accessibilityLabel("App title: chai finder")
                
                Spacer()
                
                // Refresh personalization button
                Button(action: {
                    Task {
                        await vm.refreshPersonalization()
                    }
                }) {
                    if vm.isRefreshingPersonalization {
                        ProgressView()
                            .scaleEffect(0.8)
                            .frame(width: 32, height: 32)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(DesignSystem.Colors.primary)
                            .font(.system(size: 16))
                            .frame(width: 32, height: 32)
                    }
                }
                .frame(width: 32, height: 32)
                .background(DesignSystem.Colors.primary.opacity(0.1))
                .cornerRadius(DesignSystem.CornerRadius.small)
                .disabled(vm.isRefreshingPersonalization)
                .accessibilityLabel("Refresh personalization")
                .accessibilityHint("Double tap to refresh your personalized recommendations")
                
                // Add location button - moved from floating button to header
                Button(action: {
                    // Use user's current location or map center
                    if let userLocation = locationManager.location {
                        selectedCoordinate = userLocation.coordinate
                    } else {
                        // Fallback to a default location
                        selectedCoordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
                    }
                    showingAddForm = true
                }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(DesignSystem.Colors.primary)
                        .font(.system(size: 16))
                        .frame(width: 32, height: 32)
                }
                .frame(width: 32, height: 32)
                .background(DesignSystem.Colors.primary.opacity(0.1))
                .cornerRadius(DesignSystem.CornerRadius.small)
                .accessibilityLabel("Add new chai spot")
                .accessibilityHint("Double tap to add a new chai spot")
                
                // Show My Spots button (only when not showing list)
                if !vm.isShowingList && !vm.getPersonalizedSpotIds().isEmpty {
                    Button(action: {
                        fitMapToPersonalizedSpots()
                    }) {
                        Image(systemName: "heart.fill")
                            .foregroundColor(DesignSystem.Colors.primary)
                            .font(.system(size: 16))
                            .frame(width: 32, height: 32)
                    }
                    .frame(width: 32, height: 32)
                    .background(DesignSystem.Colors.primary.opacity(0.1))
                    .cornerRadius(DesignSystem.CornerRadius.small)
                    .accessibilityLabel("Show my personalized spots")
                    .accessibilityHint("Double tap to center the map on your personalized chai spots")
                }
            }
            
            // Search Bar - restored functionality
            searchBarSection
            
            // View toggle - improved design
            HStack(spacing: DesignSystem.Spacing.sm) {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        vm.isShowingList = false
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "map")
                            .font(.system(size: 14))
                        Text("Map")
                            .font(DesignSystem.Typography.bodyMedium)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(vm.isShowingList ? DesignSystem.Colors.textSecondary : .white)
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.vertical, DesignSystem.Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                            .fill(vm.isShowingList ? Color.clear : DesignSystem.Colors.primary)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                            .stroke(vm.isShowingList ? DesignSystem.Colors.border.opacity(0.3) : Color.clear, lineWidth: 0.5)
                    )
                }
                
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        vm.isShowingList = true
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 14))
                        Text("List")
                            .font(DesignSystem.Typography.bodyMedium)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(vm.isShowingList ? .white : DesignSystem.Colors.textSecondary)
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.vertical, DesignSystem.Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                            .fill(vm.isShowingList ? DesignSystem.Colors.primary : Color.clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                            .stroke(vm.isShowingList ? Color.clear : DesignSystem.Colors.border.opacity(0.3), lineWidth: 0.5)
                    )
                }
                
                Spacer()
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            
            // Personalization reason - improved styling
            if let reason = vm.reasonText {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(DesignSystem.Colors.accent)
                        .font(.caption)
                    Text(reason)
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .multilineTextAlignment(.leading)
                    Spacer()
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.vertical, DesignSystem.Spacing.xs)
                .background(DesignSystem.Colors.accent.opacity(0.1))
                .cornerRadius(DesignSystem.CornerRadius.small)
                .padding(.horizontal, DesignSystem.Spacing.lg)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.sm) // Reduced from md to sm
        .background(DesignSystem.Colors.cardBackground)
        .shadow(
            color: Color.black.opacity(0.03), // Very subtle shadow
            radius: 2,
            x: 0,
            y: 1
        )
        .overlay(
            Rectangle()
                .frame(height: 0.5) // Reduced from 1 to 0.5 for subtler border
                .foregroundColor(DesignSystem.Colors.border.opacity(0.3)), // Reduced opacity
            alignment: .bottom
        )
    }
    
    // MARK: - Search Bar Section
    private var searchBarSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .font(.system(size: 14))
                    .accessibilityHidden(true)
                
                TextField("Search chai spots or locations...", text: $vm.searchText)
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .autocorrectionDisabled(true)
                    .autocapitalization(.none)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .textCase(.lowercase)
                    .keyboardType(.default)
                    .submitLabel(.search)
                    .textContentType(.none)
                    .focused($isSearchFocused)
                    .accessibilityLabel("Search chai spots or locations")
                    .accessibilityHint("Type to search through chai spots or search for a location to center the map")
                    .onChange(of: vm.searchText) { newValue in
                        // Debounced search
                        Task {
                            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
                            await MainActor.run {
                                if vm.searchText == newValue {
                                    handleSearch(newValue)
                                }
                            }
                        }
                    }
                    .onSubmit {
                        // Handle search submission (Enter key)
                        handleSearch(vm.searchText)
                        // Keep focus to allow continued typing
                    }
                    .disabled(vm.isSearchingLocation) // Disable while searching
                
                // Show loading indicator when searching for location
                if vm.isSearchingLocation {
                    ProgressView()
                        .scaleEffect(0.8)
                        .frame(width: 28, height: 28)
                } else if !vm.searchText.isEmpty {
                    Button(action: { 
                        withAnimation(DesignSystem.Animation.quick) {
                            vm.searchText = ""
                            vm.filterSpots("")
                            // Clear any temporary search location
                            vm.clearSearchLocation()
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .font(.system(size: 14))
                            .frame(width: 28, height: 28)
                    }
                    .accessibilityLabel("Clear search")
                    .accessibilityHint("Double tap to clear search text")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(DesignSystem.Colors.searchBackground)
            .cornerRadius(DesignSystem.CornerRadius.medium)
            .shadow(
                color: Color.black.opacity(0.04), // Very subtle shadow
                radius: 2,
                x: 0,
                y: 1
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                    .stroke(DesignSystem.Colors.border.opacity(0.08), lineWidth: 0.1)
            )
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
    }
    
    // MARK: - Search Handler
    private func handleSearch(_ searchText: String) {
        if searchText.isEmpty {
            vm.filterSpots("")
            vm.clearSearchLocation()
            return
        }
        
        // First try to filter existing spots
        vm.filterSpots(searchText)
        
        // Check if the search text looks like a location (contains common location keywords)
        if isLocationSearch(searchText) {
            // Then try to search for the location to center the map
            searchLocation(searchText)
        }
    }
    
    // MARK: - Location Search Detection
    private func isLocationSearch(_ query: String) -> Bool {
        let locationKeywords = [
            "street", "avenue", "road", "drive", "lane", "boulevard", "place", "court",
            "city", "town", "village", "neighborhood", "district", "area", "region",
            "park", "mall", "center", "plaza", "square", "station", "airport",
            "university", "college", "school", "hospital", "restaurant", "cafe",
            "coffee", "chai", "tea", "shop", "store", "market"
        ]
        
        let lowercasedQuery = query.lowercased()
        return locationKeywords.contains { lowercasedQuery.contains($0) } ||
               query.contains(",") || // Contains comma (likely address)
               query.contains(" ") || // Multiple words (likely location)
               query.count > 3 // Longer queries are more likely to be locations
    }
    
    // MARK: - Location Search
    private func searchLocation(_ query: String) {
        // Set loading state
        vm.isSearchingLocation = true
        
        let searchRequest = MKLocalSearch.Request()
        searchRequest.naturalLanguageQuery = query
        searchRequest.resultTypes = [.address, .pointOfInterest]
        
        let search = MKLocalSearch(request: searchRequest)
        search.start { response, error in
            DispatchQueue.main.async {
                // Clear loading state
                self.vm.isSearchingLocation = false
                
                if let error = error {
                    print("❌ Location search error: \(error.localizedDescription)")
                    return
                }
                
                guard let response = response, !response.mapItems.isEmpty else {
                    print("📍 No location found for query: \(query)")
                    return
                }
                
                // Use the first result to center the map
                let firstResult = response.mapItems[0]
                let coordinate = firstResult.placemark.coordinate
                
                print("📍 Found location: \(firstResult.name ?? query) at \(coordinate)")
                
                // Center the map on the found location
                self.centerMapOnSearchResult(CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude))
                
                // Add a temporary search location marker
                vm.setSearchLocation(coordinate)
                
                // Show temporary success feedback
                self.showSearchSuccessMessage(firstResult.name ?? query)
            }
        }
    }
    
    // MARK: - Search Success Feedback
    private func showSearchSuccessMessage(_ locationName: String) {
        // Show a temporary success message
        withAnimation(.easeInOut(duration: 0.3)) {
            // You could add a temporary overlay or toast message here
            // For now, we'll just print to console
            print("✅ Successfully centered map on: \(locationName)")
        }
    }
    
    // MARK: - Map Legend
    private var mapLegend: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            // Legend toggles
            HStack(spacing: DesignSystem.Spacing.md) {
                // Personalized spots toggle
                Button(action: {
                    vm.showPersonalizedOnly.toggle()
                }) {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: vm.showPersonalizedOnly ? "heart.fill" : "heart")
                            .foregroundColor(vm.showPersonalizedOnly ? DesignSystem.Colors.primary : DesignSystem.Colors.textSecondary)
                            .font(.caption)
                        Text("My Spots")
                            .font(DesignSystem.Typography.caption)
                            .fontWeight(.medium)
                            .foregroundColor(vm.showPersonalizedOnly ? DesignSystem.Colors.primary : DesignSystem.Colors.textSecondary)
                    }
                    .padding(.horizontal, DesignSystem.Spacing.sm)
                    .padding(.vertical, DesignSystem.Spacing.xs)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                            .fill(vm.showPersonalizedOnly ? DesignSystem.Colors.primary.opacity(0.1) : Color.clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                            .stroke(vm.showPersonalizedOnly ? DesignSystem.Colors.primary.opacity(0.3) : DesignSystem.Colors.border.opacity(0.3), lineWidth: 0.5)
                    )
                }
                
                // Community spots toggle
                Button(action: {
                    vm.showCommunitySpots.toggle()
                }) {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: vm.showCommunitySpots ? "cup.and.saucer.fill" : "cup.and.saucer")
                            .foregroundColor(vm.showCommunitySpots ? DesignSystem.Colors.secondary : DesignSystem.Colors.textSecondary)
                            .font(.caption)
                        Text("Community")
                            .font(DesignSystem.Typography.caption)
                            .fontWeight(.medium)
                            .foregroundColor(vm.showCommunitySpots ? DesignSystem.Colors.secondary : DesignSystem.Colors.textSecondary)
                    }
                    .padding(.horizontal, DesignSystem.Spacing.sm)
                    .padding(.vertical, DesignSystem.Spacing.xs)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                            .fill(vm.showCommunitySpots ? DesignSystem.Colors.secondary.opacity(0.1) : Color.clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                            .stroke(vm.showCommunitySpots ? DesignSystem.Colors.secondary.opacity(0.3) : DesignSystem.Colors.border.opacity(0.3), lineWidth: 0.5)
                    )
                }
                
                Spacer()
                
                // Quick actions
                Button("Show All") {
                    fitMapToAllSpots()
                }
                .font(DesignSystem.Typography.caption2)
                .foregroundColor(DesignSystem.Colors.primary)
                .padding(.horizontal, DesignSystem.Spacing.sm)
                .padding(.vertical, 2)
                .background(DesignSystem.Colors.primary.opacity(0.1))
                .cornerRadius(DesignSystem.CornerRadius.small)
            }
            
            // Search location indicator (only show when searching)
            if !vm.searchText.isEmpty && vm.hasSearchLocation {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundColor(DesignSystem.Colors.accent)
                        .font(.caption)
                    Text("🔍 Search Location")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    
                    Spacer()
                }
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .background(DesignSystem.Colors.cardBackground.opacity(0.95))
        .cornerRadius(DesignSystem.CornerRadius.small)
        .shadow(
            color: Color.black.opacity(0.05),
            radius: 3,
            x: 0,
            y: 2
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                .stroke(DesignSystem.Colors.border.opacity(0.1), lineWidth: 0.5)
        )
    }
    
    // MARK: - Map View
    private var mapViewContent: some View {
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
                // Create enhanced map view with spots
                TappableMapView(
                    initialRegion: effectiveMapRegion, // Use effectiveMapRegion
                    chaiFinder: vm.getMapSpots(),
                    personalizedSpotIds: vm.getPersonalizedSpotIds(),
                    onTap: { coordinate in
                        // Handle map tap
                        print("📍 Map tapped at: \(coordinate)")
                        // Set user interaction flag when map is tapped
                        isUserInteractingWithMap = true
                        // Store the tapped coordinate for adding new spots
                        selectedCoordinate = coordinate
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            isUserInteractingWithMap = false
                        }
                    },
                    onAnnotationTap: { spotId in
                        // Handle spot annotation tap
                        if let spot = vm.allSpots.first(where: { $0.id == spotId }) {
                            print("📍 Spot selected from map: \(spot.name)")
                            selectedSpot = spot
                            cameFromListView = false // Ensure we know this came from map
                            print("🔄 Set cameFromListView = false (will stay in map view)")
                            showingSpotDetail = true
                        }
                    },
                    onMapViewCreated: { mapView in
                        // Store reference to map view for programmatic updates
                        self.mapViewRef = mapView
                        
                        // Store the current region to prevent resetting
                        if let currentRegion = self.currentMapRegion {
                            // If we have a stored region, use it
                            mapView.setRegion(currentRegion, animated: false)
                        }
                        
                        // Store the current region periodically to prevent loss
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            self.storeCurrentMapRegion()
                        }
                    },
                    showUserLocation: true,
                    showCompass: true,
                    showScale: true
                )
                // Removed .id() modifier to prevent blinking - map updates will happen naturally
                .onAppear {
                    print("🗺️ Map view appeared with \(vm.allSpots.count) spots")
                    print("🗺️ Map spots: \(vm.allSpots.map { $0.name })")
                    print("🗺️ getMapSpots() returns: \(vm.getMapSpots().count) spots")
                }

                
                // Enhanced map controls overlay
                MapControlsOverlay(
                    mapViewRef: $mapViewRef,
                    onLocationButtonTap: {
                        centerMapOnUserLocation()
                    },
                    onZoomInTap: {
                        zoomMapIn()
                    },
                    onZoomOutTap: {
                        zoomMapOut()
                    }
                )
                
                // Quick navigation to personalized spots
                VStack {
                    // Personalized spots quick access
                    if !vm.getPersonalizedSpotIds().isEmpty {
                        personalizedSpotsQuickAccess
                    }
                    
                    Spacer()
                }
            }
        }
    }
    
    // MARK: - Personalized Spots Quick Access
    private var personalizedSpotsQuickAccess: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                ForEach(vm.allSpots.filter { vm.getPersonalizedSpotIds().contains($0.id) }.prefix(5), id: \.id) { spot in
                    Button(action: {
                        centerMapOnSpot(spot)
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: "heart.fill")
                                .font(.caption)
                                .foregroundColor(.white)
                            
                            Text(spot.name)
                                .font(DesignSystem.Typography.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .frame(maxWidth: 80)
                        }
                        .padding(.horizontal, DesignSystem.Spacing.sm)
                        .padding(.vertical, DesignSystem.Spacing.xs)
                        .background(DesignSystem.Colors.primary)
                        .cornerRadius(DesignSystem.CornerRadius.small)
                        .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                    }
                    .accessibilityLabel("Navigate to \(spot.name)")
                    .accessibilityHint("Double tap to center the map on this personalized spot")
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.top, DesignSystem.Spacing.md)
        }
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0.1), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    // MARK: - List View
    private var listView: some View {
        ZStack {
            VStack(spacing: 0) {
                // Filter options
                filterOptionsSection
                
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
    }
    
    private var filterOptionsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignSystem.Spacing.md) {
                // My Spots toggle
                Button(action: {
                    vm.togglePersonalizedOnly()
                }) {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: vm.showPersonalizedOnly ? "heart.fill" : "heart")
                            .foregroundColor(vm.showPersonalizedOnly ? DesignSystem.Colors.primary : DesignSystem.Colors.textSecondary)
                            .font(.caption)
                        Text("My Spots")
                            .font(DesignSystem.Typography.caption)
                            .fontWeight(.medium)
                            .foregroundColor(vm.showPersonalizedOnly ? DesignSystem.Colors.primary : DesignSystem.Colors.textSecondary)
                    }
                    .padding(.horizontal, DesignSystem.Spacing.sm)
                    .padding(.vertical, DesignSystem.Spacing.xs)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                            .fill(vm.showPersonalizedOnly ? DesignSystem.Colors.primary.opacity(0.1) : Color.clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                            .stroke(vm.showPersonalizedOnly ? DesignSystem.Colors.primary.opacity(0.3) : DesignSystem.Colors.border.opacity(0.3), lineWidth: 0.5)
                    )
                }
                
                // Community spots toggle
                Button(action: {
                    vm.toggleCommunitySpots()
                }) {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: vm.showCommunitySpots ? "cup.and.saucer.fill" : "cup.and.saucer")
                            .foregroundColor(vm.showCommunitySpots ? DesignSystem.Colors.secondary : DesignSystem.Colors.textSecondary)
                            .font(.caption)
                        Text("Community")
                            .font(DesignSystem.Typography.caption)
                            .fontWeight(.medium)
                            .foregroundColor(vm.showCommunitySpots ? DesignSystem.Colors.secondary : DesignSystem.Colors.textSecondary)
                    }
                    .padding(.horizontal, DesignSystem.Spacing.sm)
                    .padding(.vertical, DesignSystem.Spacing.xs)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                            .fill(vm.showCommunitySpots ? DesignSystem.Colors.secondary.opacity(0.1) : Color.clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                            .stroke(vm.showCommunitySpots ? DesignSystem.Colors.secondary.opacity(0.3) : DesignSystem.Colors.border.opacity(0.3), lineWidth: 0.5)
                    )
                }
                
                Spacer()
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
        }
        .padding(.vertical, DesignSystem.Spacing.sm)
        .background(DesignSystem.Colors.cardBackground)
        .shadow(
            color: Color.black.opacity(0.05),
            radius: 2,
            x: 0,
            y: 1
        )
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
                            .fontWeight(.medium)
                            .foregroundColor(vm.currentSortOrder == sortOrder ? .white : DesignSystem.Colors.primary)
                            .padding(.horizontal, DesignSystem.Spacing.md)
                            .padding(.vertical, DesignSystem.Spacing.sm)
                            .background(
                                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                                    .fill(vm.currentSortOrder == sortOrder ? DesignSystem.Colors.primary : Color.clear)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                                    .stroke(
                                        vm.currentSortOrder == sortOrder ? Color.clear : DesignSystem.Colors.primary.opacity(0.3), 
                                        lineWidth: 0.5
                                    )
                            )
                            .shadow(
                                color: vm.currentSortOrder == sortOrder ? Color.black.opacity(0.1) : Color.clear,
                                radius: 2,
                                x: 0,
                                y: 1
                            )
                    }
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
        }
        .padding(.vertical, DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.cardBackground)
        .shadow(
            color: Color.black.opacity(0.02),
            radius: 1,
            x: 0,
            y: 0.5
        )
    }
    
    private var spotsList: some View {
        ScrollView {
            LazyVStack(spacing: DesignSystem.Spacing.md) {
                ForEach(vm.personalizedSpots) { spot in
                    SpotCard(spot: spot, onTap: {
                        // Handle spot selection - center map on selected spot and show details
                        print("📍 Spot selected from list: \(spot.name)")
                        selectedSpot = spot
                        cameFromListView = true
                        print("🔄 Set cameFromListView = true (will return to list view)")
                        showingSpotDetail = true
                        centerMapOnSpot(spot)
                        // Switch to map view to show the selected spot
                        withAnimation(.easeInOut(duration: 0.3)) {
                            vm.isShowingList = false
                        }
                    }, viewModel: vm)
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
            
            Text("No Personalized Spots Found")
                .font(DesignSystem.Typography.headline)
                .fontWeight(.bold)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            
            Text("Try these tips to get personalized recommendations:")
                .font(DesignSystem.Typography.bodyMedium)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
            
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                ForEach(vm.getPersonalizationSuggestions(), id: \.self) { suggestion in
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(DesignSystem.Colors.accent)
                            .font(.caption)
                        Text(suggestion)
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .multilineTextAlignment(.leading)
                    }
                }
            }
            .padding(DesignSystem.Spacing.md)
            .background(DesignSystem.Colors.cardBackground)
            .cornerRadius(DesignSystem.CornerRadius.small)
        }
        .padding(DesignSystem.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignSystem.Colors.background)
    }
    
    // MARK: - Location Manager Setup
    private func setupLocationManager() {
        // Request location access for distance sorting
        locationDelegate = LocationManagerDelegate(
            viewModel: vm, 
            onLocationUpdate: { location in
                // Only update the user location, don't center the map
                self.vm.updateUserLocation(location)
            },
            checkUserInteraction: {
                self.isUserInteractingWithMap
            }
        )
        locationManager.delegate = locationDelegate
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
        
        // Don't auto-center on current location - let user control the map
        if let location = locationManager.location {
            vm.updateUserLocation(location)
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
    
    private func centerMapOnSearchResult(_ location: CLLocation) {
        guard let mapView = mapViewRef else { return }
        
        // Use a wider zoom for search results to show more context
        let newRegion = MKCoordinateRegion(
            center: location.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
        
        withAnimation(.easeInOut(duration: 0.8)) {
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
    
    // MARK: - Enhanced Map Controls
    private func centerMapOnUserLocation() {
        guard let mapView = mapViewRef,
              let userLocation = locationManager.location else { return }
        
        // Only center if user hasn't been interacting with the map recently
        if !isUserInteractingWithMap {
            let newRegion = MKCoordinateRegion(
                center: userLocation.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03)
            )
            
            withAnimation(.easeInOut(duration: 0.5)) {
                mapView.setRegion(newRegion, animated: true)
            }
        } else {
            // If user has been interacting, just update location without centering
            print("📍 User has been interacting with map - not auto-centering")
        }
    }
    
    private func zoomMapIn() {
        guard let mapView = mapViewRef else { return }
        
        let currentRegion = mapView.region
        let newSpan = MKCoordinateSpan(
            latitudeDelta: currentRegion.span.latitudeDelta * 0.5,
            longitudeDelta: currentRegion.span.longitudeDelta * 0.5
        )
        
        // Limit minimum zoom level
        let minSpan = MKCoordinateSpan(latitudeDelta: 0.001, longitudeDelta: 0.001)
        let clampedSpan = MKCoordinateSpan(
            latitudeDelta: max(minSpan.latitudeDelta, newSpan.latitudeDelta),
            longitudeDelta: max(minSpan.longitudeDelta, newSpan.longitudeDelta)
        )
        
        let newRegion = MKCoordinateRegion(center: currentRegion.center, span: clampedSpan)
        
        withAnimation(.easeInOut(duration: 0.3)) {
            mapView.setRegion(newRegion, animated: true)
        }
    }
    
    private func zoomMapOut() {
        guard let mapView = mapViewRef else { return }
        
        let currentRegion = mapView.region
        let newSpan = MKCoordinateSpan(
            latitudeDelta: currentRegion.span.latitudeDelta * 2.0,
            longitudeDelta: currentRegion.span.longitudeDelta * 2.0
        )
        
        // Limit maximum zoom level
        let maxSpan = MKCoordinateSpan(latitudeDelta: 180, longitudeDelta: 360)
        let clampedSpan = MKCoordinateSpan(
            latitudeDelta: min(maxSpan.latitudeDelta, newSpan.latitudeDelta),
            longitudeDelta: min(maxSpan.longitudeDelta, newSpan.longitudeDelta)
        )
        
        let newRegion = MKCoordinateRegion(center: currentRegion.center, span: clampedSpan)
        
        withAnimation(.easeInOut(duration: 0.3)) {
            mapView.setRegion(newRegion, animated: true)
        }
    }
    
    private func resetMapOrientation() {
        guard let mapView = mapViewRef else { return }
        
        // Reset map to north-up orientation
        let currentRegion = mapView.region
        let newRegion = MKCoordinateRegion(
            center: currentRegion.center,
            span: currentRegion.span
        )
        
        withAnimation(.easeInOut(duration: 0.3)) {
            mapView.setRegion(newRegion, animated: true)
        }
    }
    
    // MARK: - Smart Region Management
    private func fitMapToPersonalizedSpots() {
        guard let mapView = mapViewRef,
              !vm.getPersonalizedSpotIds().isEmpty else { return }
        
        let personalizedSpots = vm.allSpots.filter { vm.getPersonalizedSpotIds().contains($0.id) }
        
        if personalizedSpots.count == 1 {
            // Single spot - center on it with appropriate zoom
            centerMapOnSpot(personalizedSpots[0])
        } else if personalizedSpots.count > 1 {
            // Multiple spots - fit all in view
            let coordinates = personalizedSpots.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
            
            var minLat = coordinates[0].latitude
            var maxLat = coordinates[0].latitude
            var minLon = coordinates[0].longitude
            var maxLon = coordinates[0].longitude
            
            for coordinate in coordinates {
                minLat = min(minLat, coordinate.latitude)
                maxLat = max(maxLat, coordinate.latitude)
                minLon = min(minLon, coordinate.longitude)
                maxLon = max(maxLon, coordinate.longitude)
            }
            
            let center = CLLocationCoordinate2D(
                latitude: (minLat + maxLat) / 2,
                longitude: (minLon + maxLon) / 2
            )
            
            let span = MKCoordinateSpan(
                latitudeDelta: (maxLat - minLat) * 1.5, // Add padding
                longitudeDelta: (maxLon - minLon) * 1.5
            )
            
            let newRegion = MKCoordinateRegion(center: center, span: span)
            
            withAnimation(.easeInOut(duration: 0.8)) {
                mapView.setRegion(newRegion, animated: true)
            }
        }
    }

    private func fitMapToAllSpots() {
        guard let mapView = mapViewRef,
              !vm.allSpots.isEmpty else { return }
        
        let coordinates = vm.allSpots.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
        
        var minLat = coordinates[0].latitude
        var maxLat = coordinates[0].latitude
        var minLon = coordinates[0].longitude
        var maxLon = coordinates[0].longitude
        
        for coordinate in coordinates {
            minLat = min(minLat, coordinate.latitude)
            maxLat = max(maxLat, coordinate.latitude)
            minLon = min(minLon, coordinate.longitude)
            maxLon = max(maxLon, coordinate.longitude)
        }
        
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        
        let span = MKCoordinateSpan(
            latitudeDelta: (maxLat - minLat) * 1.5, // Add padding
            longitudeDelta: (maxLon - minLon) * 1.5
        )
        
        let newRegion = MKCoordinateRegion(center: center, span: span)
        
        withAnimation(.easeInOut(duration: 0.8)) {
            mapView.setRegion(newRegion, animated: true)
        }
    }

    private func updateMapRegion() {
        guard let mapView = mapViewRef else { return }
        
        let currentRegion = mapView.region
        
        // Store the current region to prevent resetting
        currentMapRegion = currentRegion
        
        // If user location is available, center on it
        if let userLocation = locationManager.location {
            let newRegion = MKCoordinateRegion(
                center: userLocation.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03)
            )
            withAnimation(.easeInOut(duration: 0.5)) {
                mapView.setRegion(newRegion, animated: true)
            }
            currentMapRegion = newRegion
            storeMapRegion(newRegion)
        } else if !vm.allSpots.isEmpty {
            // If no user location, try to fit all spots
            let coordinates = vm.allSpots.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
            
            var minLat = coordinates[0].latitude
            var maxLat = coordinates[0].latitude
            var minLon = coordinates[0].longitude
            var maxLon = coordinates[0].longitude
            
            for coordinate in coordinates {
                minLat = min(minLat, coordinate.latitude)
                maxLat = max(maxLat, coordinate.latitude)
                minLon = min(minLon, coordinate.longitude)
                maxLon = max(maxLon, coordinate.longitude)
            }
            
            let center = CLLocationCoordinate2D(
                latitude: (minLat + maxLat) / 2,
                longitude: (minLon + maxLon) / 2
            )
            
            let span = MKCoordinateSpan(
                latitudeDelta: (maxLat - minLat) * 1.5, // Add padding
                longitudeDelta: (maxLon - minLon) * 1.5
            )
            
            let newRegion = MKCoordinateRegion(center: center, span: span)
            
            withAnimation(.easeInOut(duration: 0.8)) {
                mapView.setRegion(newRegion, animated: true)
            }
            currentMapRegion = newRegion
            storeMapRegion(newRegion)
        }
    }
    
    // Track map region changes to prevent resetting
    private func onMapRegionChanged() {
        guard let mapView = mapViewRef else { return }
        currentMapRegion = mapView.region
    }
    
    // Store map region in UserDefaults
    private func storeMapRegion(_ region: MKCoordinateRegion) {
        let regionData: [String: Double] = [
            "latitude": region.center.latitude,
            "longitude": region.center.longitude,
            "latitudeDelta": region.span.latitudeDelta,
            "longitudeDelta": region.span.longitudeDelta
        ]
        UserDefaults.standard.set(regionData, forKey: "StoredMapRegion")
    }
    
    // Retrieve stored map region from UserDefaults
    private func getStoredMapRegion() -> MKCoordinateRegion? {
        guard let regionData = UserDefaults.standard.dictionary(forKey: "StoredMapRegion") as? [String: Double],
              let latitude = regionData["latitude"],
              let longitude = regionData["longitude"],
              let latitudeDelta = regionData["latitudeDelta"],
              let longitudeDelta = regionData["longitudeDelta"] else {
            return nil
        }
        
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            span: MKCoordinateSpan(latitudeDelta: latitudeDelta, longitudeDelta: longitudeDelta)
        )
    }
    
    // Store the current map region from the map view
    private func storeCurrentMapRegion() {
        guard let mapView = mapViewRef else { return }
        let currentRegion = mapView.region
        currentMapRegion = currentRegion
        storeMapRegion(currentRegion)
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
    let viewModel: PersonalizedMapViewModel
    
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
                    
                    // Simple rating display
                    if spot.averageRating > 0 {
                        HStack(spacing: DesignSystem.Spacing.xs) {
                            Text("\(String(format: "%.1f", spot.averageRating))★")
                                .font(DesignSystem.Typography.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(DesignSystem.Colors.ratingGreen)
                                .cornerRadius(DesignSystem.CornerRadius.small)
                            
                            Text("\(spot.ratingCount) reviews")
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                    }
                    
                    // Personalization score line
                    let personalizationScore = viewModel.calculatePersonalizationScore(for: spot)
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: "heart")
                            .font(.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        Text("Match: \(String(format: "%.1f", personalizationScore))/5")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    
                    // Simple personalization indicator
                    if personalizationScore >= 3.5 {
                        HStack(spacing: DesignSystem.Spacing.xs) {
                            Image(systemName: "heart.fill")
                                .font(.caption)
                                .foregroundColor(DesignSystem.Colors.primary)
                            Text("Great match for you")
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.primary)
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
            .shadow(
                color: Color.black.opacity(0.04),
                radius: 2,
                x: 0,
                y: 1
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                    .stroke(DesignSystem.Colors.border.opacity(0.08), lineWidth: 0.1)
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
    @Published var isRefreshingPersonalization = false
    @Published var hasError = false
    @Published var errorMessage: String?
    @Published var isShowingList = false {
        didSet {
            print("🔄 ViewModel isShowingList changed from \(oldValue) to \(isShowingList)")
        }
    }
    @Published var userLocation: CLLocation? // Added this line
    @Published var searchText: String = "" // Added this line
    @Published var hasSearchLocation: Bool = false // Track if search location is active
    @Published var isSearchingLocation: Bool = false // Track if location search is in progress
    
    // Map update trigger to avoid blinking
    @Published var mapUpdateTrigger = UUID()
    
    // Filter state
    @Published var showFriendsFavorites = true
    @Published var showPersonalizedOnly = true
    @Published var showCommunitySpots = true // Added this line
    @Published var currentSortOrder: SortOrder = .personalization
    
    // Personalization data
    @Published var userProfile: UserProfile?
    private var userRatings: [Rating] = []
    private var friendRatings: [Rating] = []
    
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
    
    // MARK: - Personalization Methods
    
    /// Load user profile and ratings for personalization
    func loadUserData() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        let db = Firestore.firestore()
        
        // Load user profile
        do {
            let profileDoc = try await db.collection("users").document(uid).getDocument()
            if let data = profileDoc.data() {
                await MainActor.run {
                    self.userProfile = UserProfile(
                        id: profileDoc.documentID,
                        uid: data["uid"] as? String ?? uid,
                        displayName: data["displayName"] as? String ?? "Unknown User",
                        email: data["email"] as? String ?? "unknown",
                        photoURL: data["photoURL"] as? String,
                        friends: data["friends"] as? [String] ?? [],
                        incomingRequests: data["incomingRequests"] as? [String] ?? [],
                        outgoingRequests: data["outgoingRequests"] as? [String] ?? [],
                        bio: data["bio"] as? String,
                        hasTasteSetup: data["hasTasteSetup"] as? Bool ?? false,
                        tasteVector: data["tasteVector"] as? [Int],
                        topTasteTags: data["topTasteTags"] as? [String]
                    )
                }
            }
        } catch {
            print("❌ Failed to load user profile: \(error)")
        }
        
        // Load user's ratings
        do {
            let ratingsSnapshot = try await db.collection("ratings")
                .whereField("userId", isEqualTo: uid)
                .getDocuments()
            
            self.userRatings = ratingsSnapshot.documents.compactMap { doc -> Rating? in
                let data = doc.data()
                guard let spotId = data["spotId"] as? String,
                      let userId = data["userId"] as? String,
                      let value = data["value"] as? Int else { return nil }
                
                                    return Rating(
                        id: doc.documentID,
                        spotId: spotId,
                        userId: userId,
                        username: data["username"] as? String ?? data["userName"] as? String,
                        spotName: data["spotName"] as? String,
                        value: value,
                        comment: data["comment"] as? String,
                        timestamp: (data["timestamp"] as? Timestamp)?.dateValue(),
                        likes: data["likes"] as? Int,
                        dislikes: data["dislikes"] as? Int,
                        creaminessRating: data["creaminessRating"] as? Int,
                        chaiStrengthRating: data["chaiStrengthRating"] as? Int,
                        flavorNotes: data["flavorNotes"] as? [String]
                    )
            }
        } catch {
            print("❌ Failed to load user ratings: \(error)")
        }
        
        // Load friend ratings if user has friends
        if let friends = userProfile?.friends, !friends.isEmpty {
            do {
                let friendRatingsSnapshot = try await db.collection("ratings")
                    .whereField("userId", in: friends)
                    .getDocuments()
                
                self.friendRatings = friendRatingsSnapshot.documents.compactMap { doc -> Rating? in
                    let data = doc.data()
                    guard let spotId = data["spotId"] as? String,
                          let userId = data["userId"] as? String,
                          let value = data["value"] as? Int else { return nil }
                    
                                    return Rating(
                    id: doc.documentID,
                    spotId: spotId,
                    userId: userId,
                    username: data["username"] as? String ?? data["userName"] as? String,
                    spotName: data["spotName"] as? String,
                    value: value,
                    comment: data["comment"] as? String,
                    timestamp: (data["timestamp"] as? Timestamp)?.dateValue(),
                    likes: data["likes"] as? Int,
                    dislikes: data["dislikes"] as? Int,
                    creaminessRating: data["creaminessRating"] as? Int,
                    chaiStrengthRating: data["chaiStrengthRating"] as? Int,
                    flavorNotes: data["flavorNotes"] as? [String]
                )
                }
            } catch {
                print("❌ Failed to load friend ratings: \(error)")
            }
        }
    }
    
    /// Calculate personalization score for a spot (returns 1-5 rating)
    func calculatePersonalizationScore(for spot: ChaiSpot) -> Double {
        var rawScore: Double = 0.0
        var maxPossibleScore: Double = 0.0
        
        // Base score from user's taste preferences
        if let tasteVector = userProfile?.tasteVector, tasteVector.count >= 2 {
            let preferredCreaminess = tasteVector[0]
            let preferredStrength = tasteVector[1]
            
            // Find user's rating for this spot to get their preferences
            if let userRating = userRatings.first(where: { $0.spotId == spot.id }) {
                if let creaminessRating = userRating.creaminessRating {
                    let creaminessMatch = 5.0 - Double(abs(creaminessRating - preferredCreaminess))
                    rawScore += creaminessMatch * 2.0 // Weight creaminess preference
                    maxPossibleScore += 10.0 // Max creaminess score
                }
                
                if let strengthRating = userRating.chaiStrengthRating {
                    let strengthMatch = 5.0 - Double(abs(strengthRating - preferredStrength))
                    rawScore += strengthMatch * 2.0 // Weight strength preference
                    maxPossibleScore += 10.0 // Max strength score
                }
                
                // Bonus for high user rating
                rawScore += Double(userRating.value) * 3.0
                maxPossibleScore += 15.0 // Max user rating score
            }
            
            // Flavor notes matching
            if let topTasteTags = userProfile?.topTasteTags {
                let matchingFlavors = spot.chaiTypes.filter { chaiType in
                    topTasteTags.contains { tag in
                        chaiType.localizedCaseInsensitiveContains(tag)
                    }
                }
                rawScore += Double(matchingFlavors.count) * 5.0
                maxPossibleScore += Double(topTasteTags.count) * 5.0 // Max flavor score
            }
        }
        
        // Friend recommendations bonus
        let friendRatingsForSpot = friendRatings.filter { $0.spotId == spot.id }
        if !friendRatingsForSpot.isEmpty {
            let averageFriendRating = Double(friendRatingsForSpot.reduce(0) { $0 + $1.value }) / Double(friendRatingsForSpot.count)
            rawScore += averageFriendRating * 2.0
            maxPossibleScore += 10.0 // Max friend rating score
        }
        
        // Community rating bonus
        rawScore += spot.averageRating * 1.5
        maxPossibleScore += 7.5 // Max community rating score (5 * 1.5)
        
        // Rating count bonus (more ratings = more reliable)
        let ratingCountBonus = min(Double(spot.ratingCount) * 0.5, 10.0)
        rawScore += ratingCountBonus
        maxPossibleScore += 10.0 // Max rating count bonus
        
        // Convert to 1-5 scale
        if maxPossibleScore > 0 {
            let normalizedScore = (rawScore / maxPossibleScore) * 5.0
            // Ensure it's between 1.0 and 5.0
            return max(1.0, min(5.0, normalizedScore))
        } else {
            // Fallback: base score on community rating if no personalization data
            return max(1.0, min(5.0, spot.averageRating))
        }
    }
    
    /// Get personalized spot IDs for map labeling
    func getPersonalizedSpotIds() -> Set<String> {
        let personalizedSpots = allSpots.filter { spot in
            let score = calculatePersonalizationScore(for: spot)
            let isPersonalized = score >= 3.5 // Threshold for considering a spot "personalized" (3.5/5 = 70%)
            
            // Special case: always include newly added spots (rating count = 1 and created by current user)
            if spot.ratingCount == 1 {
                // We can't easily check if created by current user without additional data,
                // so let's include all spots with rating count 1 for now
                return true
            }
            
            return isPersonalized
        }
        return Set(personalizedSpots.map { $0.id })
    }
    
    /// Get personalization breakdown for a specific spot
    func getPersonalizationBreakdown(for spot: ChaiSpot) -> [String: Double] {
        var breakdown: [String: Double] = [:]
        
        // Taste preference matching
        if let tasteVector = userProfile?.tasteVector, tasteVector.count >= 2 {
            let preferredCreaminess = tasteVector[0]
            let preferredStrength = tasteVector[1]
            
            if let userRating = userRatings.first(where: { $0.spotId == spot.id }) {
                if let creaminessRating = userRating.creaminessRating {
                    let creaminessMatch = 5.0 - Double(abs(creaminessRating - preferredCreaminess))
                    breakdown["Creaminess Match"] = creaminessMatch * 2.0
                }
                
                if let strengthRating = userRating.chaiStrengthRating {
                    let strengthMatch = 5.0 - Double(abs(strengthRating - preferredStrength))
                    breakdown["Strength Match"] = strengthMatch * 2.0
                }
                
                breakdown["Your Rating"] = Double(userRating.value) * 3.0
            }
            
            // Flavor notes matching
            if let topTasteTags = userProfile?.topTasteTags {
                let matchingFlavors = spot.chaiTypes.filter { chaiType in
                    topTasteTags.contains { tag in
                        chaiType.localizedCaseInsensitiveContains(tag)
                    }
                }
                breakdown["Flavor Match"] = Double(matchingFlavors.count) * 5.0
            }
        }
        
        // Friend recommendations
        let friendRatingsForSpot = friendRatings.filter { $0.spotId == spot.id }
        if !friendRatingsForSpot.isEmpty {
            let averageFriendRating = Double(friendRatingsForSpot.reduce(0) { $0 + $1.value }) / Double(friendRatingsForSpot.count)
            breakdown["Friend Recommendations"] = averageFriendRating * 2.0
        }
        
        // Community rating
        breakdown["Community Rating"] = spot.averageRating * 1.5
        
        // Rating count bonus
        breakdown["Rating Count"] = min(Double(spot.ratingCount) * 0.5, 10.0)
        
        return breakdown
    }
    
    /// Get explanation for why a spot is personalized
    func getPersonalizationExplanation(for spot: ChaiSpot) -> String {
        let score = calculatePersonalizationScore(for: spot)
        let breakdown = getPersonalizationBreakdown(for: spot)
        var explanations: [String] = []
        
        if let creaminessMatch = breakdown["Creaminess Match"], creaminessMatch > 0 {
            explanations.append("matches your creaminess preference")
        }
        
        if let strengthMatch = breakdown["Strength Match"], strengthMatch > 0 {
            explanations.append("matches your strength preference")
        }
        
        if let flavorMatch = breakdown["Flavor Match"], flavorMatch > 0 {
            explanations.append("has your favorite flavors")
        }
        
        if let friendRecs = breakdown["Friend Recommendations"], friendRecs > 0 {
            explanations.append("recommended by friends")
        }
        
        if let communityRating = breakdown["Community Rating"], communityRating > 0 {
            explanations.append("highly rated by community")
        }
        
        if explanations.isEmpty {
            return "Based on general popularity and ratings"
        }
        
        let scoreDescription = if score >= 4.5 { "excellent match" } else if score >= 3.5 { "good match" } else if score >= 2.5 { "moderate match" } else { "low match" }
        
        return "This spot is a \(scoreDescription) (\(String(format: "%.1f", score))/5) because it " + explanations.joined(separator: ", ")
    }
    
    /// Get suggestions for improving personalization
    func getPersonalizationSuggestions() -> [String] {
        var suggestions: [String] = []
        
        if userProfile?.hasTasteSetup != true {
            suggestions.append("Complete taste onboarding to get personalized recommendations")
        }
        
        if userRatings.isEmpty {
            suggestions.append("Rate some chai spots to help us understand your preferences")
        }
        
        if let friends = userProfile?.friends, friends.isEmpty {
            suggestions.append("Add friends to see their recommendations")
        }
        
        if suggestions.isEmpty {
            suggestions.append("Your preferences are well set up! Try rating more spots for better recommendations")
        }
        
        return suggestions
    }
    
    /// Get personalization statistics for the user
    func getPersonalizationStats() -> [String: Any] {
        let personalizedIds = getPersonalizedSpotIds()
        let personalizedSpots = allSpots.filter { personalizedIds.contains($0.id) }
        
        let totalScore = personalizedSpots.reduce(0.0) { $0 + calculatePersonalizationScore(for: $1) }
        let averageScore = personalizedSpots.isEmpty ? 0.0 : totalScore / Double(personalizedSpots.count)
        
        return [
            "totalPersonalized": personalizedSpots.count,
            "totalSpots": allSpots.count,
            "personalizationPercentage": allSpots.isEmpty ? 0.0 : Double(personalizedSpots.count) / Double(allSpots.count) * 100.0,
            "averageScore": averageScore,
            "hasTasteSetup": userProfile?.hasTasteSetup ?? false,
            "totalRatings": userRatings.count,
            "totalFriends": userProfile?.friends?.count ?? 0
        ]
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

    func toggleCommunitySpots() {
        showCommunitySpots.toggle()
        applyFilters()
    }
    
    private func applyFilters() {
        var filtered = allSpots
        
        if !showPersonalizedOnly {
            filtered = filtered.filter { spot in
                let score = calculatePersonalizationScore(for: spot)
                return score < 3.5 // Exclude personalized spots (3.5/5 = 70%)
            }
        }
        
        if !showCommunitySpots {
            filtered = filtered.filter { spot in
                let score = calculatePersonalizationScore(for: spot)
                return score >= 3.5 // Only show personalized spots (3.5/5 = 70%)
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
            // Sort by personalization score
            personalizedSpots.sort { spot1, spot2 in
                let score1 = calculatePersonalizationScore(for: spot1)
                let score2 = calculatePersonalizationScore(for: spot2)
                return score1 > score2
            }
            
        case .distance:
            guard let userLocation = self.userLocation else {
                // If no user location, fall back to personalization sorting
                sortSpots(by: .personalization)
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
        print("🔄 loadAllSpots() called")
        await MainActor.run {
            isLoading = true
        }
        
        // Load user data for personalization
        await loadUserData()
        
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
                    
                    return spot
                }
                
                allSpots.append(contentsOf: spots)
                
            } catch {
                print("❌ Error loading from collection \(collectionName): \(error)")
                continue
            }
        }
        
        print("📚 Total spots loaded: \(allSpots.count)")
        
        // Remove duplicates based on spot ID
        let uniqueSpots = Array(Set(allSpots))
        
        await MainActor.run {
            self.allSpots = uniqueSpots
            self.isLoading = false
            self.loadPersonalizedSpots()
            self.applyFilters()
        }
    }
    
    func loadPersonalizedSpots() {
        // Apply personalization logic
        let personalizedIds = getPersonalizedSpotIds()
        
        let personalizedSpots = allSpots.filter { personalizedIds.contains($0.id) }
        
        self.personalizedSpots = personalizedSpots
        
        // Generate reason text based on user preferences
        if let tasteVector = userProfile?.tasteVector, tasteVector.count >= 2 {
            let creaminess = tasteVector[0]
            let strength = tasteVector[1]
            
            var reasons: [String] = []
            
            if creaminess >= 4 {
                reasons.append("rich, creamy chai")
            } else if creaminess <= 2 {
                reasons.append("light, refreshing chai")
            } else {
                reasons.append("balanced creaminess")
            }
            
            if strength >= 4 {
                reasons.append("bold, intense flavors")
            } else if strength <= 2 {
                reasons.append("mild, gentle varieties")
            } else {
                reasons.append("moderately strong chai")
            }
            
            if let topTasteTags = userProfile?.topTasteTags, !topTasteTags.isEmpty {
                reasons.append("your favorite flavors: \(topTasteTags.joined(separator: ", "))")
            }
            
            reasonText = "Personalized for you"
        } else {
            reasonText = "Based on community ratings and friend recommendations"
        }
    }
    
    func filterSpots(_ searchText: String) {
        if searchText.isEmpty {
            personalizedSpots = allSpots
        } else {
            personalizedSpots = allSpots.filter { spot in
                spot.name.localizedCaseInsensitiveContains(searchText) ||
                spot.address.localizedCaseInsensitiveContains(searchText) ||
                spot.chaiTypes.contains(where: { $0.localizedCaseInsensitiveContains(searchText) })
            }
        }
        sortSpots(by: currentSortOrder)
    }
    
    func setSearchLocation(_ coordinate: CLLocationCoordinate2D) {
        // This method is called when a location search result is found.
        // It can be used to add a temporary annotation or marker to the map.
        // For now, we'll just update the user location for distance sorting.
        // If you want to show a temporary marker, you'd add it to the mapViewRef.
        // For example:
        // if let mapView = mapViewRef {
        //     let annotation = MKPointAnnotation()
        //     annotation.title = "Searched Location"
        //     mapView.addAnnotation(annotation)
        // }
        hasSearchLocation = true
        updateUserLocation(CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude))
    }
    
    func clearSearchLocation() {
        // This method is called when the user clears the search text.
        // It can be used to remove any temporary markers or reset user location.
        // For now, we'll just clear the user location.
        hasSearchLocation = false
        updateUserLocation(CLLocation(latitude: 37.7749, longitude: -122.4194)) // Fallback to default
    }
    
    /// Refresh personalization data and recalculate personalized spots
    func refreshPersonalization() async {
        await MainActor.run {
            isRefreshingPersonalization = true
        }
        
        await loadUserData()
        
        await MainActor.run {
            loadPersonalizedSpots()
            applyFilters()
            isRefreshingPersonalization = false
        }
    }
    
    /// Add a new chai spot to Firestore
    func addNewChaiSpot(name: String, address: String, rating: Int, comments: String, chaiTypes: [String], coordinate: CLLocationCoordinate2D, creaminessRating: Int, chaiStrengthRating: Int, flavorNotes: [String]) async -> Bool {
        print("🔄 Starting to add new chai spot...")
        print("  - Name: \(name)")
        print("  - Address: \(address)")
        print("  - Rating: \(rating)")
        print("  - Comments: \(comments)")
        print("  - Chai Types: \(chaiTypes)")
        print("  - Coordinate: \(coordinate)")
        print("  - Creaminess Rating: \(creaminessRating)")
        print("  - Chai Strength Rating: \(chaiStrengthRating)")
        print("  - Flavor Notes: \(flavorNotes)")
        
        guard let userId = Auth.auth().currentUser?.uid else {
            print("❌ User not authenticated")
            return false
        }
        
        print("✅ User authenticated: \(userId)")
        let db = Firestore.firestore()
        
        do {
            // Create the chai spot document
            let spotData: [String: Any] = [
                "name": name,
                "address": address,
                "latitude": coordinate.latitude,
                "longitude": coordinate.longitude,
                "chaiTypes": chaiTypes,
                "averageRating": Double(rating),
                "ratingCount": 1,
                "createdBy": userId,
                "createdAt": Timestamp(),
                "updatedAt": Timestamp()
            ]
            
            print("📝 Spot data prepared: \(spotData)")
            
            // Add to chaiFinder collection (primary collection)
            let spotRef = try await db.collection("chaiFinder").addDocument(data: spotData)
            let spotId = spotRef.documentID
            
            print("✅ New chai spot added with ID: \(spotId)")
            
            // Try to add to chaiSpots collection for consistency, but don't fail if it doesn't work
            do {
                try await db.collection("chaiSpots").document(spotId).setData(spotData)
                print("✅ Also added to chaiSpots collection")
            } catch {
                print("⚠️ Warning: Failed to add to chaiSpots collection: \(error.localizedDescription)")
                print("⚠️ This is not critical - the spot was added to chaiFinder collection")
            }
            
            // Create the user's rating for this spot
            let ratingData: [String: Any] = [
                "spotId": spotId,
                "userId": userId,
                "username": Auth.auth().currentUser?.displayName ?? "Anonymous",
                "spotName": name,
                "value": rating,
                "comment": comments,
                "timestamp": Timestamp(),
                "likes": 0,
                "dislikes": 0,
                "creaminessRating": creaminessRating,
                "chaiStrengthRating": chaiStrengthRating,
                "flavorNotes": flavorNotes,
                "visibility": "public",
                "deleted": false,
                "updatedAt": Timestamp()
            ]
            
            print("📝 Rating data prepared: \(ratingData)")
            
            try await db.collection("ratings").addDocument(data: ratingData)
            print("✅ User rating added for new spot")
            
            // Reload user ratings to include the new one
            print("🔄 Reloading user ratings to include the new rating...")
            await loadUserData()
            print("✅ User ratings reloaded")
            
            // Reload spots to include the new one
            print("🔄 Reloading spots to include the new one...")
            await loadAllSpots()
            print("✅ Spots reloaded")
            
            // Check if the new spot is now in the allSpots array
            await MainActor.run {
                if let newSpot = self.allSpots.first(where: { $0.name == name }) {
                    print("✅ New spot '\(name)' found in allSpots array after reload")
                    print("✅ Total spots in allSpots: \(self.allSpots.count)")
                    print("✅ Map view should now show \(self.allSpots.count) spots")
                    
                    // Trigger map update without blinking
                    self.mapUpdateTrigger = UUID()
                    print("🔄 Map update triggered")
                    
                    // Post notification to trigger map refresh
                    NotificationCenter.default.post(name: .spotsUpdated, object: nil)
                    print("📢 Posted spotsUpdated notification")
                    
                    // Map updates happen naturally through the view model's published properties
                } else {
                    print("❌ New spot '\(name)' NOT found in allSpots array after reload")
                    print("❌ Available spots: \(self.allSpots.map { $0.name })")
                }
            }
            
            return true
            
        } catch {
            print("❌ Failed to add new chai spot: \(error.localizedDescription)")
            print("❌ Error details: \(error)")
            return false
        }
    }
    
    /// Get map spots for the map view
    func getMapSpots() -> [ChaiFinder] {
        let mapSpots = allSpots.map { spot in
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
        
        return mapSpots
    }
}

struct PersonalizedMapView_Previews: PreviewProvider {
    static var previews: some View {
        PersonalizedMapView()
            .environmentObject(SessionStore())
    }
}
