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

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        print("🗺️ TappableMapView updating with \(chaiFinder.count) spots")
        
        // Remove existing annotations (except user location and search pin)
        let annotationsToRemove = mapView.annotations.filter { annotation in
            !(annotation is MKUserLocation) && annotation.title != "Search Location"
        }
        mapView.removeAnnotations(annotationsToRemove)

        // Add enhanced annotations with rich data
        for spot in chaiFinder {
            let annotation = EnhancedChaiAnnotation(spot: spot, isPersonalized: personalizedSpotIds.contains(spot.id ?? ""))
            mapView.addAnnotation(annotation)
        }
        
        print("✅ TappableMapView updated with \(mapView.annotations.count) annotations")

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

        init(_ parent: TappableMapView) {
            self.parent = parent
        }

        // MARK: - Enhanced Annotation Handling
        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            guard let annotation = view.annotation else { return }
            
            if let enhancedAnnotation = annotation as? EnhancedChaiAnnotation {
                // Handle enhanced chai spot annotation
                parent.onAnnotationTap?(enhancedAnnotation.spotId)
            } else if annotation.title == "Search Location" {
                // Handle search location annotation
                print("🔍 Search location selected")
            }
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
            
            // Handle enhanced chai annotations
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
                    // Configure marker appearance
                    if enhancedAnnotation.isPersonalized {
                        markerView.markerTintColor = DesignSystem.Colors.primary.toUIColor()
                        markerView.glyphText = "🫖"
                        markerView.glyphTintColor = .white
                    } else {
                        markerView.markerTintColor = DesignSystem.Colors.secondary.toUIColor()
                        markerView.glyphText = "☕"
                        markerView.glyphTintColor = .white
                    }
                    
                    // Add callout with rich information
                    let calloutView = createCalloutView(for: enhancedAnnotation)
                    markerView.detailCalloutAccessoryView = calloutView
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
            // Mark that user is interacting when region changes
            isUserInteracting = true
        }
        
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            // Reset interaction flag after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.isUserInteracting = false
            }
        }
    }
}

// MARK: - Enhanced Chai Annotation
class EnhancedChaiAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let title: String?
    let subtitle: String?
    let spotId: String
    let averageRating: Double
    let ratingCount: Int
    let isPersonalized: Bool
    
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
