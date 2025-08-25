import Foundation

struct ReviewFeedItem: Identifiable {
    let id: String
    let spotId: String
    var spotName: String // Made mutable so it can be updated
    var spotAddress: String // Made mutable so it can be updated
    let userId: String
    let username: String
    let rating: Int
    let comment: String?
    let timestamp: Date
    let chaiType: String?
    
    // New rating fields
    let creaminessRating: Int?
    let chaiStrengthRating: Int?
    let flavorNotes: [String]?
    
    // 🎮 NEW: Photo and gamification fields
    let photoURL: String?
    let hasPhoto: Bool
    let gamificationScore: Int
    let isFirstReview: Bool
    let isNewSpot: Bool
    
    // 🎮 NEW: Social reactions field
    let reactions: [String: Int]
    
    // MARK: - Computed Properties for Enhanced Search
    
    /// Extracts city name from the address field
    var cityName: String {
        let addressComponents = spotAddress.components(separatedBy: ",")
        if addressComponents.count >= 2 {
            // Usually city is the second-to-last component before state/zip
            let cityComponent = addressComponents[addressComponents.count - 2].trimmingCharacters(in: .whitespaces)
            return cityComponent
        }
        return spotAddress
    }
    
    /// Extracts neighborhood/area from the address field
    var neighborhood: String {
        let addressComponents = spotAddress.components(separatedBy: ",")
        if addressComponents.count >= 3 {
            // Neighborhood might be in the first component after street address
            let neighborhoodComponent = addressComponents[1].trimmingCharacters(in: .whitespaces)
            return neighborhoodComponent
        }
        return ""
    }
    
    /// Extracts state from the address field
    var state: String {
        let addressComponents = spotAddress.components(separatedBy: ",")
        if addressComponents.count >= 2 {
            // State is usually the last component
            let stateComponent = addressComponents.last?.trimmingCharacters(in: .whitespaces) ?? ""
            return stateComponent
        }
        return ""
    }
    
    /// Creates a searchable text that includes all relevant location information
    var searchableLocationText: String {
        var searchText = spotName
        searchText += " " + spotAddress
        searchText += " " + cityName
        searchText += " " + neighborhood
        searchText += " " + state
        return searchText.lowercased()
    }
    
    /// Creates a searchable text that includes all review content
    var searchableReviewText: String {
        var searchText = username
        if let comment = comment {
            searchText += " " + comment
        }
        if let chaiType = chaiType {
            searchText += " " + chaiType
        }
        if let flavorNotes = flavorNotes {
            searchText += " " + flavorNotes.joined(separator: " ")
        }
        return searchText.lowercased()
    }
} 