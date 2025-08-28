import SwiftUI
import MapKit
import UIKit

// MARK: - Color Extensions
extension Color {
    func toUIColor() -> UIColor {
        return UIColor(self)
    }
}

// MARK: - Enhanced Map View
struct TappableMapView: UIViewRepresentable {
    var initialRegion: MKCoordinateRegion
    var chaiFinder: [ChaiFinder]
    var personalizedSpotIds: Set<String> = []
    var onTap: (CLLocationCoordinate2D) -> Void
    var onAnnotationTap: ((String) -> Void)? = nil
    var tempSearchCoordinate: CLLocationCoordinate2D? = nil
    var onMapViewCreated: ((MKMapView) -> Void)? = nil
    var onDebugClustering: (() -> Void)? = nil
    
    // New properties for enhanced UX
    var showUserLocation: Bool = true
    var showCompass: Bool = true
    var showScale: Bool = true
    var showTraffic: Bool = false
    var mapType: MKMapType = .standard

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        
        // Enhanced map configuration
        mapView.setRegion(initialRegion, animated: false)
        mapView.delegate = context.coordinator
        
        // Basic annotation view registration for reuse
        mapView.register(MKMarkerAnnotationView.self, forAnnotationViewWithReuseIdentifier: "ChaiSpot")
        
        // Test distance calculation for debugging
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            context.coordinator.testDistanceCalculation(in: mapView)
        }
        
        // Enable user location
        if showUserLocation {
            mapView.showsUserLocation = true
            mapView.userTrackingMode = .none
        }
        
        // Map appearance and controls
        mapView.showsCompass = showCompass
        mapView.showsScale = showScale
        mapView.showsTraffic = showTraffic
        mapView.mapType = mapType
        
        // Enhanced gesture handling
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        tapGesture.cancelsTouchesInView = false
        mapView.addGestureRecognizer(tapGesture)
        
        // Add double-tap gesture for zoom (but don't interfere with normal map gestures)
        let doubleTapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDoubleTap(_:)))
        doubleTapGesture.numberOfTapsRequired = 2
        doubleTapGesture.cancelsTouchesInView = false
        mapView.addGestureRecognizer(doubleTapGesture)
        
        // Don't add custom pinch gesture - let the map handle its own zoom
        // This prevents conflicts with the built-in map zoom behavior
        
        // Notify parent that map view is created
        onMapViewCreated?(mapView)
        
        // Add debug clustering callback
        if let onDebugClustering = onDebugClustering {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                onDebugClustering()
            }
        }

        return mapView
    }
    
    // MARK: - Clustering Logic
    private func createClusteredAnnotations(for spots: [ChaiFinder], in mapView: MKMapView) -> [EnhancedChaiAnnotation] {
        guard !spots.isEmpty else { return [] }
        
        let dynamicDistance = calculateDynamicDistance(for: mapView)
        print("🔍 Creating clusters with distance threshold: \(dynamicDistance)")
        
        var clusteredAnnotations: [EnhancedChaiAnnotation] = []
        var processedSpots = Set<String>()
        
        for spot in spots {
            // Skip if already processed
            guard let spotId = spot.id, !processedSpots.contains(spotId) else { continue }
            
            // Find all nearby spots including this one
            let nearbySpots = findNearbySpots(to: spot, within: dynamicDistance, in: spots)
            
            if nearbySpots.count == 1 {
                // Single spot - create individual annotation
                let annotation = EnhancedChaiAnnotation(
                    spot: spot,
                    isPersonalized: personalizedSpotIds.contains(spotId)
                )
                clusteredAnnotations.append(annotation)
                processedSpots.insert(spotId)
                print("📍 Single spot: \(spot.name)")
            } else {
                // Multiple spots - create clustered annotation
                let representativeSpot = findRepresentativeSpot(for: nearbySpots)
                let annotation = EnhancedChaiAnnotation(
                    spot: representativeSpot,
                    isPersonalized: personalizedSpotIds.contains(representativeSpot.id ?? "")
                )
                
                // Store cluster information
                annotation.clusterSize = nearbySpots.count
                annotation.clusteredSpots = nearbySpots
                
                clusteredAnnotations.append(annotation)
                
                // Mark all spots in this cluster as processed
                for nearbySpot in nearbySpots {
                    if let nearbyId = nearbySpot.id {
                        processedSpots.insert(nearbyId)
                    }
                }
                
                print("🎯 Cluster created: \(nearbySpots.count) spots around \(representativeSpot.name)")
            }
        }
        
        print("✅ Created \(clusteredAnnotations.count) annotations from \(spots.count) spots")
        return clusteredAnnotations
    }
    
    private func findNearbySpots(to spot: ChaiFinder, within distance: Double, in allSpots: [ChaiFinder]) -> [ChaiFinder] {
        let spotCoord = CLLocationCoordinate2D(latitude: spot.latitude, longitude: spot.longitude)
        
        return allSpots.filter { otherSpot in
            let otherCoord = CLLocationCoordinate2D(latitude: otherSpot.latitude, longitude: otherSpot.longitude)
            let calculatedDistance = calculateGeographicDistance(from: spotCoord, to: otherCoord)
            return calculatedDistance < distance
        }
    }
    
    private func findRepresentativeSpot(for spots: [ChaiFinder]) -> ChaiFinder {
        // Use the first spot as representative, or find the one closest to the center
        guard spots.count > 1 else { return spots[0] }
        
        // Calculate the center point of all spots
        let totalLat = spots.reduce(0) { $0 + $1.latitude }
        let totalLon = spots.reduce(0) { $0 + $1.longitude }
        let centerLat = totalLat / Double(spots.count)
        let centerLon = totalLon / Double(spots.count)
        let centerCoord = CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon)
        
        // Find the spot closest to the center
        var closestSpot = spots[0]
        var minDistance = Double.infinity
        
        for spot in spots {
            let spotCoord = CLLocationCoordinate2D(latitude: spot.latitude, longitude: spot.longitude)
            let distance = calculateGeographicDistance(from: centerCoord, to: spotCoord)
            if distance < minDistance {
                minDistance = distance
                closestSpot = spot
            }
        }
        
        return closestSpot
    }
    
    private func calculateDynamicDistance(for mapView: MKMapView) -> Double {
        let span = mapView.region.span
        let zoomLevel = span.latitudeDelta
        
        print("🗺️ Current map zoom level: \(zoomLevel)")
        
        // Dynamic distance calculation:
        // - At high zoom (close up): smaller threshold to group very close locations
        // - At low zoom (zoomed out): larger threshold to group more locations
        let dynamicDistance: Double
        if zoomLevel < 0.001 {
            // Very zoomed in - group very close locations
            dynamicDistance = 0.0005
            print("🔍 Very high zoom - using distance threshold: \(dynamicDistance)")
        } else if zoomLevel < 0.005 {
            // Moderately zoomed in - group nearby locations
            dynamicDistance = 0.002
            print("🔍 High zoom - using distance threshold: \(dynamicDistance)")
        } else if zoomLevel < 0.02 {
            // Medium zoom - group moderately close locations
            dynamicDistance = 0.005
            print("🔍 Medium zoom - using distance threshold: \(dynamicDistance)")
        } else if zoomLevel < 0.05 {
            // Zoomed out - group locations in same area
            dynamicDistance = 0.01
            print("🔍 Low zoom - using distance threshold: \(dynamicDistance)")
        } else {
            // Very zoomed out - group locations in same region
            dynamicDistance = 0.02
            print("🔍 Very low zoom - using distance threshold: \(dynamicDistance)")
        }
        
        return dynamicDistance
    }
    
    private func calculateGeographicDistance(from coord1: CLLocationCoordinate2D, to coord2: CLLocationCoordinate2D) -> Double {
        let lat1 = coord1.latitude * .pi / 180
        let lon1 = coord1.longitude * .pi / 180
        let lat2 = coord2.latitude * .pi / 180
        let lon2 = coord2.longitude * .pi / 180
        
        let dLat = lat2 - lat1
        let dLon = lon2 - lon1
        
        let a = sin(dLat/2) * sin(dLat/2) + cos(lat1) * cos(lat2) * sin(dLon/2) * sin(dLon/2)
        let c = 2 * atan2(sqrt(a), sqrt(1-a))
        
        // Convert to degrees for consistency with our threshold
        return c * 180 / .pi
    }
    func updateUIView(_ mapView: MKMapView, context: Context) {
        print("🗺️ TappableMapView updating with \(chaiFinder.count) spots")
        
        // Check if we just refreshed clustering - if so, don't re-cluster
        if context.coordinator.justRefreshedClustering {
            print("⏭️ Skipping re-clustering in updateUIView - just refreshed")
            return
        }
        
        // Remove existing annotations (except user location and search pin)
        let annotationsToRemove = mapView.annotations.filter { annotation in
            !(annotation is MKUserLocation) && annotation.title != "Search Location"
        }
        mapView.removeAnnotations(annotationsToRemove)

        // Create clustered annotations instead of individual ones
        let clusteredAnnotations = createClusteredAnnotations(for: chaiFinder, in: mapView)
        
        // Add clustered annotations
        for annotation in clusteredAnnotations {
            mapView.addAnnotation(annotation)
        }
        
        print("✅ TappableMapView updated with \(clusteredAnnotations.count) clustered annotations")

        // Add temporary search pin if available
        if let tempSearchCoordinate = tempSearchCoordinate {
            let tempPin = MKPointAnnotation()
            tempPin.coordinate = tempSearchCoordinate
            tempPin.title = "Search Location"
            mapView.addAnnotation(tempPin)
        }
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: TappableMapView
        private var isUserInteracting = false
        private var pendingClusteringRefresh: DispatchWorkItem?
        var justRefreshedClustering = false
        private var lastProcessedZoomLevel: Double?

        init(_ parent: TappableMapView) {
            self.parent = parent
        }

        // MARK: - Enhanced Annotation Handling
        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            guard let annotation = view.annotation else { return }
            
            // Handle enhanced chai spot annotation
            if let enhancedAnnotation = annotation as? EnhancedChaiAnnotation {
                parent.onAnnotationTap?(enhancedAnnotation.spotId)
            } else if annotation.title == "Search Location" {
                // Handle search location annotation
                print("🔍 Search location selected")
            }
        }
        
        func mapView(_ mapView: MKMapView, didDeselect view: MKAnnotationView) {
            // Clear any animations when annotation is deselected
            view.layer.removeAnimation(forKey: "pulse")
            view.transform = .identity
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            // Handle user location
            if annotation is MKUserLocation {
                return nil // Use default user location view
            }
            
            // Handle search location
            if annotation.title == "Search Location" {
                let view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: "SearchPin")
                view.markerTintColor = .systemBlue
                view.glyphText = "🔍"
                view.canShowCallout = true
                return view
            }
            
            // Handle enhanced chai annotations (individual locations)
            if let enhancedAnnotation = annotation as? EnhancedChaiAnnotation {
                let identifier = enhancedAnnotation.isPersonalized ? "PersonalizedPin" : "CommunityPin"
                
                var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
                if annotationView == nil {
                    annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                    annotationView?.canShowCallout = true
                } else {
                    annotationView?.annotation = annotation
                }
                
                if let markerView = annotationView as? MKMarkerAnnotationView {
                    // Configure marker appearance - will be updated based on clustering
                    if enhancedAnnotation.isPersonalized {
                        markerView.markerTintColor = DesignSystem.Colors.primary.toUIColor()
                        markerView.glyphTintColor = .white
                    } else {
                        markerView.markerTintColor = DesignSystem.Colors.secondary.toUIColor()
                        markerView.glyphTintColor = .white
                    }
                    
                    // Use the clustering information from the annotation
                    if enhancedAnnotation.isClustered {
                        // This is a clustered annotation
                        print("🎯 Clustered annotation: \(enhancedAnnotation.clusterSize) locations")
                        
                        // Show count directly on the marker
                        markerView.glyphText = "\(enhancedAnnotation.clusterSize)"
                        markerView.glyphTintColor = .white
                        
                        // Add subtle animation for clustered markers
                        UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseInOut], animations: {
                            markerView.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
                        })
                        
                        // Add a subtle pulse effect to draw attention to clustered markers
                        let pulseAnimation = CABasicAnimation(keyPath: "transform.scale")
                        pulseAnimation.duration = 2.0
                        pulseAnimation.fromValue = 1.0
                        pulseAnimation.toValue = 1.05
                        pulseAnimation.autoreverses = true
                        pulseAnimation.repeatCount = .infinity
                        markerView.layer.add(pulseAnimation, forKey: "pulse")
                        
                        // Create a grouped callout using the stored clustered spots
                        let groupedCalloutView = createSimpleGroupedCalloutView(for: enhancedAnnotation.clusteredSpots)
                        markerView.detailCalloutAccessoryView = groupedCalloutView
                        
                        // Ensure the callout can be shown
                        markerView.canShowCallout = true
                        
                        print("✅ Added grouped callout with \(enhancedAnnotation.clusterSize) locations")
                        print("📍 Marker now shows count: \(enhancedAnnotation.clusterSize)")
                    } else {
                        // Single location - show individual callout
                        print("📍 Single location - showing individual callout")
                        
                        // Show appropriate icon for single location
                        if enhancedAnnotation.isPersonalized {
                            markerView.glyphText = "🫖"
                        } else {
                            markerView.glyphText = "☕"
                        }
                        
                        let calloutView = createCalloutView(for: enhancedAnnotation)
                        markerView.detailCalloutAccessoryView = calloutView
                        markerView.canShowCallout = true
                        
                        print("📍 Single location marker configured with icon")
                    }
                }
                
                return annotationView
            }
            
            return nil
        }
        
        // MARK: - Callout Creation
        private func createCalloutView(for annotation: EnhancedChaiAnnotation) -> UIView {
            let containerView = UIView()
            containerView.translatesAutoresizingMaskIntoConstraints = false
            
            let stackView = UIStackView()
            stackView.axis = .vertical
            stackView.spacing = 8
            stackView.translatesAutoresizingMaskIntoConstraints = false
            
            // Spot name
            let nameLabel = UILabel()
            nameLabel.text = annotation.title
            nameLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
            nameLabel.textColor = .label
            
            // Address
            let addressLabel = UILabel()
            addressLabel.text = annotation.subtitle
            addressLabel.font = UIFont.systemFont(ofSize: 14)
            addressLabel.textColor = .secondaryLabel
            addressLabel.numberOfLines = 2
            
            // Rating info
            let ratingLabel = UILabel()
            if annotation.averageRating > 0 {
                ratingLabel.text = "⭐ \(String(format: "%.1f", annotation.averageRating)) (\(annotation.ratingCount) ratings)"
            } else {
                ratingLabel.text = "No ratings yet"
            }
            ratingLabel.font = UIFont.systemFont(ofSize: 12)
            ratingLabel.textColor = .secondaryLabel
            
            // Personalization indicator
            if annotation.isPersonalized {
                let personalizationLabel = UILabel()
                personalizationLabel.text = "🫖 Personalized for you"
                personalizationLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)
                personalizationLabel.textColor = DesignSystem.Colors.primary.toUIColor()
                
                stackView.addArrangedSubview(personalizationLabel)
            }
            
            stackView.addArrangedSubview(nameLabel)
            stackView.addArrangedSubview(addressLabel)
            stackView.addArrangedSubview(ratingLabel)
            
            containerView.addSubview(stackView)
            
            NSLayoutConstraint.activate([
                stackView.topAnchor.constraint(equalTo: containerView.topAnchor),
                stackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                stackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                stackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
                containerView.widthAnchor.constraint(equalToConstant: 200)
            ])
            
            return containerView
        }
        
        // MARK: - Simple Grouped Callout Creation
        private func createSimpleGroupedCalloutView(for locations: [ChaiFinder]) -> UIView {
            let containerView = UIView()
            containerView.translatesAutoresizingMaskIntoConstraints = false
            
            let stackView = UIStackView()
            stackView.axis = .vertical
            stackView.spacing = 8
            stackView.translatesAutoresizingMaskIntoConstraints = false
            
            // Header
            let headerLabel = UILabel()
            headerLabel.text = "\(locations.count) locations nearby"
            headerLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
            headerLabel.textColor = .label
            stackView.addArrangedSubview(headerLabel)
            
            // Location list (show max 5)
            for (index, location) in locations.prefix(5).enumerated() {
                let locationView = createSimpleLocationRowView(for: location, index: index + 1)
                stackView.addArrangedSubview(locationView)
            }
            
            if locations.count > 5 {
                let moreLabel = UILabel()
                moreLabel.text = "... and \(locations.count - 5) more"
                moreLabel.font = UIFont.systemFont(ofSize: 12)
                moreLabel.textColor = .secondaryLabel
                stackView.addArrangedSubview(moreLabel)
            }
            
            containerView.addSubview(stackView)
            
            NSLayoutConstraint.activate([
                stackView.topAnchor.constraint(equalTo: containerView.topAnchor),
                stackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                stackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                stackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
                containerView.widthAnchor.constraint(equalToConstant: 250)
            ])
            
            return containerView
        }
        
        private func createSimpleLocationRowView(for location: ChaiFinder, index: Int) -> UIView {
            let rowView = UIView()
            rowView.translatesAutoresizingMaskIntoConstraints = false
            
            let nameLabel = UILabel()
            nameLabel.text = "\(index). \(location.name)"
            nameLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
            nameLabel.textColor = .label
            
            let addressLabel = UILabel()
            addressLabel.text = location.address
            addressLabel.font = UIFont.systemFont(ofSize: 12)
            addressLabel.textColor = .secondaryLabel
            addressLabel.numberOfLines = 1
            
            rowView.addSubview(nameLabel)
            rowView.addSubview(addressLabel)
            
            NSLayoutConstraint.activate([
                nameLabel.topAnchor.constraint(equalTo: rowView.topAnchor, constant: 4),
                nameLabel.leadingAnchor.constraint(equalTo: rowView.leadingAnchor),
                nameLabel.trailingAnchor.constraint(equalTo: rowView.trailingAnchor),
                
                addressLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
                addressLabel.leadingAnchor.constraint(equalTo: rowView.leadingAnchor),
                addressLabel.trailingAnchor.constraint(equalTo: rowView.trailingAnchor),
                addressLabel.bottomAnchor.constraint(equalTo: rowView.bottomAnchor, constant: -4)
            ])
            
            return rowView
        }
        
        // MARK: - Distance Testing (for debugging)
        func testDistanceCalculation(in mapView: MKMapView) {
            print("🧪 Testing distance calculation...")
            
            if parent.chaiFinder.count < 2 {
                print("⚠️ Need at least 2 spots to test distance calculation")
                return
            }
            
            let spot1 = parent.chaiFinder[0]
            let spot2 = parent.chaiFinder[1]
            
            let coord1 = CLLocationCoordinate2D(latitude: spot1.latitude, longitude: spot1.longitude)
            let coord2 = CLLocationCoordinate2D(latitude: spot2.latitude, longitude: spot2.longitude)
            
            let euclideanDistance = sqrt(
                pow(coord1.latitude - coord2.latitude, 2) + 
                pow(coord1.longitude - coord2.longitude, 2)
            )
            
            let geographicDistance = calculateGeographicDistance(from: coord1, to: coord2)
            
            print("🧪 Distance between '\(spot1.name)' and '\(spot2.name)':")
            print("🧪   Euclidean: \(euclideanDistance)")
            print("🧪   Geographic: \(geographicDistance)")
            print("🧪 Spot 1: \(coord1.latitude), \(coord1.longitude)")
            print("🧪 Spot 2: \(coord2.latitude), \(coord2.longitude)")
            
            // Test if they would be grouped using the new clustering logic
            let dynamicDistance = calculateDynamicDistance(for: mapView)
            let nearbySpots = findNearbySpots(to: spot1, within: dynamicDistance, in: parent.chaiFinder)
            print("🧪 Would '\(spot1.name)' be grouped? \(nearbySpots.count > 1 ? "Yes" : "No")")
            print("🧪 Nearby spots count: \(nearbySpots.count)")
        }
        
        // MARK: - Manual Annotation Refresh (for testing)
        func refreshAnnotations(in mapView: MKMapView) {
            print("🔄 Manually refreshing annotations...")
            
            // Remove all existing annotations
            let existingAnnotations = mapView.annotations.filter { !($0 is MKUserLocation) }
            mapView.removeAnnotations(existingAnnotations)
            
            // Re-add all annotations
            for spot in parent.chaiFinder {
                let annotation = EnhancedChaiAnnotation(
                    spot: spot,
                    isPersonalized: parent.personalizedSpotIds.contains(spot.id ?? "")
                )
                mapView.addAnnotation(annotation)
            }
            
            print("✅ Refreshed \(parent.chaiFinder.count) annotations")
        }
        
        // Debug method to test clustering manually
        func debugClustering(in mapView: MKMapView) {
            print("🐛 DEBUG: Testing clustering manually...")
            
            // Log current map state
            print("🐛 Current map region: \(mapView.region)")
            print("🐛 Total annotations: \(mapView.annotations.count)")
            print("🐛 Total chai spots: \(parent.chaiFinder.count)")
            
            // Test clustering for each annotation
            for annotation in mapView.annotations {
                if let enhancedAnnotation = annotation as? EnhancedChaiAnnotation {
                    if enhancedAnnotation.isClustered {
                        print("🐛 Clustered annotation '\(enhancedAnnotation.title ?? "unknown")': \(enhancedAnnotation.clusterSize) locations")
                    } else {
                        print("🐛 Single annotation '\(enhancedAnnotation.title ?? "unknown")': 1 location")
                    }
                }
            }
            
            // Force a refresh
            refreshAnnotationsForClustering(in: mapView)
        }
        
        // Public method to manually trigger clustering refresh
        func manualClusteringRefresh(in mapView: MKMapView) {
            print("🔄 Manual clustering refresh triggered")
            refreshAnnotationsForClustering(in: mapView)
        }
        
        // Refresh annotations specifically for clustering updates
        func refreshAnnotationsForClustering(in mapView: MKMapView) {
            print("🔄 Refreshing annotations for clustering...")
            
            // Set flag to prevent updateUIView from re-clustering
            justRefreshedClustering = true
            
            // Clear any existing animations first
            for annotation in mapView.annotations {
                if let annotationView = mapView.view(for: annotation) {
                    annotationView.layer.removeAnimation(forKey: "pulse")
                    annotationView.transform = .identity
                }
            }
            
            // COMPLETELY RECREATE CLUSTERS based on current zoom level
            // This is the key fix - we need to re-cluster, not just refresh views
            
            // Remove all existing chai annotations (keep user location and search pins)
            let chaiAnnotations = mapView.annotations.filter { annotation in
                annotation is EnhancedChaiAnnotation
            }
            mapView.removeAnnotations(chaiAnnotations)
            
            // Re-create clustered annotations with current zoom level
            let newClusteredAnnotations = createClusteredAnnotations(for: parent.chaiFinder, in: mapView)
            
            // Add the new clustered annotations
            for annotation in newClusteredAnnotations {
                mapView.addAnnotation(annotation)
            }
            
            print("✅ Re-clustered annotations: \(newClusteredAnnotations.count) from \(parent.chaiFinder.count) spots")
            print("🗺️ New zoom level: \(mapView.region.span.latitudeDelta)")
            
            // Reset the flag after a longer delay to prevent rapid re-clustering
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.justRefreshedClustering = false
                print("✅ Clustering refresh flag reset - ready for next update")
            }
        }
        
        // MARK: - Enhanced Close Location Detection (DEPRECATED - now using pre-clustered annotations)
        // This method is kept for backward compatibility but is no longer used
        private func findCloseLocations(to coordinate: CLLocationCoordinate2D, in mapView: MKMapView, within distance: Double = 0.005) -> [ChaiFinder] {
            // Return empty array as clustering is now handled during annotation creation
            print("⚠️ findCloseLocations is deprecated - clustering now handled during annotation creation")
            return []
        }
        
        // Calculate geographic distance using Haversine formula for more accuracy
        private func calculateGeographicDistance(from coord1: CLLocationCoordinate2D, to coord2: CLLocationCoordinate2D) -> Double {
            let lat1 = coord1.latitude * .pi / 180
            let lon1 = coord1.longitude * .pi / 180
            let lat2 = coord2.latitude * .pi / 180
            let lon2 = coord2.longitude * .pi / 180
            
            let dLat = lat2 - lat1
            let dLon = lon2 - lon1
            
            let a = sin(dLat/2) * sin(dLat/2) + cos(lat1) * cos(lat2) * sin(dLon/2) * sin(dLon/2)
            let c = 2 * atan2(sqrt(a), sqrt(1-a))
            
            // Convert to degrees for consistency with our threshold
            return c * 180 / .pi
        }
        
        // Calculate dynamic distance based on current map zoom level
        private func calculateDynamicDistance(for mapView: MKMapView) -> Double {
            let span = mapView.region.span
            let zoomLevel = span.latitudeDelta
            
            print("🗺️ Current map zoom level: \(zoomLevel)")
            
            // IMPROVED Dynamic distance calculation with more sensitive thresholds:
            // - At very high zoom: NO clustering (show all individual locations)
            // - At high zoom: only cluster extremely close locations
            // - At medium zoom: minimal clustering
            // - At low zoom: moderate clustering
            let dynamicDistance: Double
            if zoomLevel < 0.001 {
                // Very zoomed in - NO CLUSTERING, show all individual locations
                dynamicDistance = 0.0
                print("🔍 Very high zoom - NO CLUSTERING, showing all individual locations")
            } else if zoomLevel < 0.002 {
                // High zoom - only cluster extremely close locations (same building)
                dynamicDistance = 0.0001
                print("🔍 High zoom - minimal clustering, threshold: \(dynamicDistance)")
            } else if zoomLevel < 0.005 {
                // Moderately zoomed in - minimal clustering
                dynamicDistance = 0.0003
                print("🔍 Moderate zoom - minimal clustering, threshold: \(dynamicDistance)")
            } else if zoomLevel < 0.01 {
                // Medium zoom - light clustering
                dynamicDistance = 0.001
                print("🔍 Medium zoom - light clustering, threshold: \(dynamicDistance)")
            } else if zoomLevel < 0.02 {
                // Low zoom - moderate clustering
                dynamicDistance = 0.003
                print("🔍 Low zoom - moderate clustering, threshold: \(dynamicDistance)")
            } else {
                // Very zoomed out - aggressive clustering
                dynamicDistance = 0.008
                print("🔍 Very low zoom - aggressive clustering, threshold: \(dynamicDistance)")
            }
            
            return dynamicDistance
        }
        
        // MARK: - Enhanced Gesture Handling
        @objc func handleTap(_ sender: UITapGestureRecognizer) {
            guard let mapView = sender.view as? MKMapView else { return }
            let location = sender.location(in: mapView)

            if let hitView = mapView.hitTest(location, with: nil), hitView is MKAnnotationView {
                return
            }

            let coordinate = mapView.convert(location, toCoordinateFrom: mapView)
            parent.onTap(coordinate)
        }
        
        // MARK: - Clustering Logic
        private func createClusteredAnnotations(for spots: [ChaiFinder], in mapView: MKMapView) -> [EnhancedChaiAnnotation] {
            guard !spots.isEmpty else { return [] }
            
            let dynamicDistance = calculateDynamicDistance(for: mapView)
            print("🔍 Creating clusters with distance threshold: \(dynamicDistance)")
            
            // SPECIAL CASE: No clustering at very high zoom
            if dynamicDistance == 0.0 {
                print("🔍 NO CLUSTERING - creating individual annotations for all spots")
                var individualAnnotations: [EnhancedChaiAnnotation] = []
                
                for spot in spots {
                    guard let spotId = spot.id else { continue }
                    let annotation = EnhancedChaiAnnotation(
                        spot: spot,
                        isPersonalized: parent.personalizedSpotIds.contains(spotId)
                    )
                    individualAnnotations.append(annotation)
                }
                
                print("✅ Created \(individualAnnotations.count) individual annotations (no clustering)")
                return individualAnnotations
            }
            
            var clusteredAnnotations: [EnhancedChaiAnnotation] = []
            var processedSpots = Set<String>()
            
            for spot in spots {
                // Skip if already processed
                guard let spotId = spot.id, !processedSpots.contains(spotId) else { continue }
                
                // Find all nearby spots including this one
                let nearbySpots = findNearbySpots(to: spot, within: dynamicDistance, in: spots)
                
                if nearbySpots.count == 1 {
                    // Single spot - create individual annotation
                    let annotation = EnhancedChaiAnnotation(
                        spot: spot,
                        isPersonalized: parent.personalizedSpotIds.contains(spotId)
                    )
                    clusteredAnnotations.append(annotation)
                    processedSpots.insert(spotId)
                    print("📍 Single spot: \(spot.name)")
                } else {
                    // Multiple spots - create clustered annotation
                    let representativeSpot = findRepresentativeSpot(for: nearbySpots)
                    let annotation = EnhancedChaiAnnotation(
                        spot: representativeSpot,
                        isPersonalized: parent.personalizedSpotIds.contains(representativeSpot.id ?? "")
                    )
                    
                    // Store cluster information
                    annotation.clusterSize = nearbySpots.count
                    annotation.clusteredSpots = nearbySpots
                    
                    clusteredAnnotations.append(annotation)
                    
                    // Mark all spots in this cluster as processed
                    for nearbySpot in nearbySpots {
                        if let nearbyId = nearbySpot.id {
                            processedSpots.insert(nearbyId)
                        }
                    }
                    
                    print("🎯 Cluster created: \(nearbySpots.count) spots around \(representativeSpot.name)")
                }
            }
            
            print("✅ Created \(clusteredAnnotations.count) annotations from \(spots.count) spots")
            return clusteredAnnotations
        }
        
        private func findNearbySpots(to spot: ChaiFinder, within distance: Double, in allSpots: [ChaiFinder]) -> [ChaiFinder] {
            let spotCoord = CLLocationCoordinate2D(latitude: spot.latitude, longitude: spot.longitude)
            
            return allSpots.filter { otherSpot in
                let otherCoord = CLLocationCoordinate2D(latitude: otherSpot.latitude, longitude: otherSpot.longitude)
                let calculatedDistance = calculateGeographicDistance(from: spotCoord, to: otherCoord)
                return calculatedDistance < distance
            }
        }
        
        private func findRepresentativeSpot(for spots: [ChaiFinder]) -> ChaiFinder {
            // Use the first spot as representative, or find the one closest to the center
            guard spots.count > 1 else { return spots[0] }
            
            // Calculate the center point of all spots
            let totalLat = spots.reduce(0) { $0 + $1.latitude }
            let totalLon = spots.reduce(0) { $0 + $1.longitude }
            let centerLat = totalLat / Double(spots.count)
            let centerLon = totalLon / Double(spots.count)
            let centerCoord = CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon)
            
            // Find the spot closest to the center
            var closestSpot = spots[0]
            var minDistance = Double.infinity
            
            for spot in spots {
                let spotCoord = CLLocationCoordinate2D(latitude: spot.latitude, longitude: spot.longitude)
                let distance = calculateGeographicDistance(from: centerCoord, to: spotCoord)
                if distance < minDistance {
                    minDistance = distance
                    closestSpot = spot
                }
            }
            
            return closestSpot
        }
        
        @objc func handleDoubleTap(_ sender: UITapGestureRecognizer) {
            guard let mapView = sender.view as? MKMapView else { return }
            let location = sender.location(in: mapView)
            let coordinate = mapView.convert(location, toCoordinateFrom: mapView)
            
            // Zoom in on double-tap location
            let currentRegion = mapView.region
            let newSpan = MKCoordinateSpan(
                latitudeDelta: currentRegion.span.latitudeDelta * 0.5,
                longitudeDelta: currentRegion.span.longitudeDelta * 0.5
            )
            let newRegion = MKCoordinateRegion(center: coordinate, span: newSpan)
            
            withAnimation(.easeInOut(duration: 0.3)) {
                mapView.setRegion(newRegion, animated: true)
            }
        }
        
        // MARK: - Map Region Management
        func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
            // Set interaction flag when user starts moving the map
            isUserInteracting = true
        }
        
        // Refresh annotations when region changes to update clustering
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            // Reset interaction flag after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.isUserInteracting = false
            }
            
            // IMPROVED: Intelligent clustering refresh with better debouncing
            // Cancel any pending refresh to avoid multiple rapid updates
            if let pendingRefresh = pendingClusteringRefresh {
                pendingRefresh.cancel()
            }
            
            // Only refresh if we haven't just refreshed and the zoom level has changed significantly
            let currentZoom = mapView.region.span.latitudeDelta
            let lastZoom = lastProcessedZoomLevel ?? currentZoom
            
            // Only refresh if zoom changed by more than 10% to prevent excessive updates
            let zoomChangeRatio = abs(currentZoom - lastZoom) / lastZoom
            let shouldRefresh = zoomChangeRatio > 0.1 || abs(currentZoom - lastZoom) > 0.001
            
            if shouldRefresh && !justRefreshedClustering {
                print("🔄 Zoom level changed significantly: \(lastZoom) → \(currentZoom) (ratio: \(zoomChangeRatio))")
                
                // Debounced clustering refresh - wait for user to stop zooming
                let workItem = DispatchWorkItem {
                    self.lastProcessedZoomLevel = currentZoom
                    self.refreshAnnotationsForClustering(in: mapView)
                }
                pendingClusteringRefresh = workItem
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: workItem) // Increased to 800ms
            } else {
                print("⏭️ Skipping refresh - zoom change too small or just refreshed")
            }
        }
        
        // MARK: - Annotation Management
        func mapView(_ mapView: MKMapView, didAdd views: [MKAnnotationView]) {
            // Ensure annotations are properly spaced and visible
            for view in views {
                if let annotation = view.annotation as? EnhancedChaiAnnotation {
                    // Make sure the annotation is visible
                    view.isHidden = false
                }
            }
        }
        
        func mapView(_ mapView: MKMapView, willAdd views: [MKAnnotationView]) {
            // Prepare annotations for addition with proper spacing
            for view in views {
                if let annotation = view.annotation as? EnhancedChaiAnnotation {
                    // Ensure the annotation view is properly configured
                    view.canShowCallout = true
                }
            }
        }
    }
}

// MARK: - Enhanced Chai Annotation
class EnhancedChaiAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    var title: String?
    let subtitle: String?
    let spotId: String
    let averageRating: Double
    let ratingCount: Int
    let isPersonalized: Bool
    
    // Clustering properties
    var clusterSize: Int = 1
    var clusteredSpots: [ChaiFinder] = []
    
    var isClustered: Bool {
        return clusterSize > 1
    }
    
    init(spot: ChaiFinder, isPersonalized: Bool) {
        self.coordinate = CLLocationCoordinate2D(latitude: spot.latitude, longitude: spot.longitude)
        self.title = spot.name
        self.subtitle = spot.address
        self.spotId = spot.id ?? ""
        self.averageRating = spot.averageRating ?? 0.0
        self.ratingCount = spot.ratingCount ?? 0
        self.isPersonalized = isPersonalized
        super.init()
    }
}

// MARK: - Map Controls Overlay
struct MapControlsOverlay: View {
    @Binding var mapViewRef: MKMapView?
    let onLocationButtonTap: () -> Void
    let onZoomInTap: () -> Void
    let onZoomOutTap: () -> Void
    let onCompassTap: () -> Void
    
    var body: some View {
        VStack {
            Spacer()
            
            HStack {
                Spacer()
                
                VStack(spacing: DesignSystem.Spacing.sm) {
                    // Location button
                    Button(action: onLocationButtonTap) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(DesignSystem.Colors.primary)
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                    }
                    .accessibilityLabel("Center on your location")
                    .accessibilityHint("Double tap to center the map on your current location")
                    
                    // Zoom controls
                    VStack(spacing: 2) {
                        Button(action: onZoomInTap) {
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(DesignSystem.Colors.primary)
                                .clipShape(Circle())
                                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                        }
                        .accessibilityLabel("Zoom in")
                        .accessibilityHint("Double tap to zoom in on the map")
                        
                        Button(action: onZoomOutTap) {
                            Image(systemName: "minus")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(DesignSystem.Colors.primary)
                                .clipShape(Circle())
                                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                        }
                        .accessibilityLabel("Zoom out")
                        .accessibilityHint("Double tap to zoom out on the map")
                    }
                    
                    // Compass button
                    Button(action: onCompassTap) {
                        Image(systemName: "location.north.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(DesignSystem.Colors.primary)
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                    }
                    .accessibilityLabel("Reset map orientation")
                    .accessibilityHint("Double tap to reset the map to north-up orientation")
                }
                .padding(.trailing, DesignSystem.Spacing.lg)
                .padding(.bottom, DesignSystem.Spacing.lg)
            }
        }
    }
}
