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


