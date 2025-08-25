import SwiftUI
import MapKit
import UIKit

// MARK: - Color Extensions
extension Color {
    func toUIColor() -> UIColor {
        return UIColor(self)
    }
}

struct TappableMapView: UIViewRepresentable {
    var initialRegion: MKCoordinateRegion
    var chaiFinder: [ChaiFinder]
    var personalizedSpotIds: Set<String> = []  // 🆕 Track which spots are personalized
    var onTap: (CLLocationCoordinate2D) -> Void
    var onAnnotationTap: ((String) -> Void)? = nil
    var tempSearchCoordinate: CLLocationCoordinate2D? = nil
    var onMapViewCreated: ((MKMapView) -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.setRegion(initialRegion, animated: false)
        mapView.delegate = context.coordinator

        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        tapGesture.cancelsTouchesInView = false
        mapView.addGestureRecognizer(tapGesture)
        
        // Notify parent that map view is created
        onMapViewCreated?(mapView)

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        print("🗺️ TappableMapView updating with \(chaiFinder.count) spots")
        
        // NEVER update the region after initial setup - preserve user interactions
        // Only update annotations when spots change
        
        mapView.removeAnnotations(mapView.annotations)

        for spot in chaiFinder {
            let annotation = MKPointAnnotation()
            annotation.coordinate = CLLocationCoordinate2D(latitude: spot.latitude, longitude: spot.longitude)
            annotation.title = spot.name
            mapView.addAnnotation(annotation)
        }
        print("✅ TappableMapView updated with \(mapView.annotations.count) annotations")

        // 🆕 Add temp search pin if available
        if let tempSearchCoordinate = tempSearchCoordinate {
            let tempPin = MKPointAnnotation()
            tempPin.coordinate = tempSearchCoordinate
            tempPin.title = "Search Location"
            mapView.addAnnotation(tempPin)
        }
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: TappableMapView

        init(_ parent: TappableMapView) {
            self.parent = parent
        }

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            guard let annotation = view.annotation else { return }
            let tappedCoordinate = annotation.coordinate

            if let tappedSpot = parent.chaiFinder.first(where: {
                abs($0.latitude - tappedCoordinate.latitude) < 0.0001 &&
                abs($0.longitude - tappedCoordinate.longitude) < 0.0001
            }) {
                parent.onAnnotationTap?(tappedSpot.id ?? "")
            }
        }

        @objc func handleTap(_ sender: UITapGestureRecognizer) {
            guard let mapView = sender.view as? MKMapView else { return }
            let location = sender.location(in: mapView)

            if let hitView = mapView.hitTest(location, with: nil), hitView is MKAnnotationView {
                return
            }

            let coordinate = mapView.convert(location, toCoordinateFrom: mapView)
            parent.onTap(coordinate)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            let identifier = "CustomPin"

            if annotation.title == "Search Location" {
                let view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: "SearchPin")
                view.markerTintColor = .systemBlue
                view.glyphText = "🔍"
                return view
            }

            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            if annotationView == nil {
                annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = true
            } else {
                annotationView?.annotation = annotation
            }
            
            // 🆕 Color-code annotations based on personalization
            if let annotationView = annotationView as? MKMarkerAnnotationView {
                // Find the corresponding spot to check if it's personalized
                if let spot = parent.chaiFinder.first(where: { spot in
                    abs(spot.latitude - annotation.coordinate.latitude) < 0.0001 &&
                    abs(spot.longitude - annotation.coordinate.longitude) < 0.0001
                }) {
                    if parent.personalizedSpotIds.contains(spot.id ?? "") {
                        // Personalized spot - use primary color (orange)
                        annotationView.markerTintColor = DesignSystem.Colors.primary.toUIColor()
                        annotationView.glyphText = "🫖"
                    } else {
                        // General community spot - use secondary color (orange secondary)
                        annotationView.markerTintColor = DesignSystem.Colors.secondary.toUIColor()
                        annotationView.glyphText = "☕"
                    }
                }
            }

            return annotationView
        }
        

    }
}
