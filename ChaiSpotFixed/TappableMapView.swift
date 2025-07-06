import SwiftUI
import MapKit

struct TappableMapView: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    var chaiFinder: [ChaiFinder]
    var onTap: (CLLocationCoordinate2D) -> Void
    var onAnnotationTap: ((String) -> Void)? = nil
    var tempSearchCoordinate: CLLocationCoordinate2D? = nil  // 🆕

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.setRegion(region, animated: false)
        mapView.delegate = context.coordinator

        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        tapGesture.cancelsTouchesInView = false
        mapView.addGestureRecognizer(tapGesture)

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        mapView.setRegion(region, animated: true)
        mapView.removeAnnotations(mapView.annotations)

        for spot in chaiFinder {
            let annotation = MKPointAnnotation()
            annotation.coordinate = CLLocationCoordinate2D(latitude: spot.latitude, longitude: spot.longitude)
            annotation.title = spot.name
            mapView.addAnnotation(annotation)
        }

        // 🆕 Add temp search pin if available
        if let tempCoord = tempSearchCoordinate {
            let tempPin = MKPointAnnotation()
            tempPin.coordinate = tempCoord
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

            return annotationView
        }
    }
}
