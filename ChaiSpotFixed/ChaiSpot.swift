import Foundation
import FirebaseFirestoreSwift
import CoreLocation

struct ChaiFinder: Identifiable, Codable {
    @DocumentID var id: String?
    var name: String
    var latitude: Double
    var longitude: Double
    var address: String
    var chaiTypes: [String]
    var averageRating: Double?
    var ratingCount: Int? // ✅ add this
}

// MARK: - Chai Spot Model for UI
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


