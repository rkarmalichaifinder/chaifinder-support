import Foundation
import FirebaseFirestore

struct Rating: Identifiable, Codable {
    var id: String?
    var spotId: String
    var userId: String
    var username: String?  // Optional display name for the reviewer
    var spotName: String?  // Name of the spot being rated
    var value: Int         // Rating value, e.g., 1–5
    var comment: String?
    var timestamp: Date?
    var likes: Int?
    var dislikes: Int?
    
    // New rating fields
    var creaminessRating: Int?
    var chaiStrengthRating: Int?
    var flavorNotes: [String]?
    var chaiType: String?
    
    // 🎮 NEW GAMIFICATION FIELDS
    var photoURL: String?                    // ✅ Photo of the chai
    var hasPhoto: Bool = false               // ✅ Whether review includes photo
    var reactions: [String: Int] = [:]       // ✅ Social reactions (cheers, love, wow)
    var isStreakReview: Bool = false         // ✅ Whether this review extends user's streak
    var gamificationScore: Int = 0           // ✅ Points earned for this review
    var isFirstReview: Bool = false          // ✅ Whether this is user's first review
    var isNewSpot: Bool = false              // ✅ Whether this is a new spot for the user
    
    // 🔒 PRIVACY FIELD
    var visibility: String = "public"        // ✅ "public", "friends", "private"
    
    // 🎯 NEW: Reaction types
    enum ReactionType: String, CaseIterable, Codable {
        case disagree = "disagree"
        case love = "love"
        case wow = "wow"
        case helpful = "helpful"
        
        var emoji: String {
            switch self {
            case .disagree: return "👎"
            case .love: return "❤️"
            case .wow: return "😮"
            case .helpful: return "👍"
            }
        }
        
        var displayName: String {
            switch self {
            case .disagree: return "Disagree"
            case .love: return "Love"
            case .wow: return "Wow"
            case .helpful: return "Helpful"
            }
        }
    }
    
    // 🏆 NEW: Calculate gamification score for this rating
    var calculatedScore: Int {
        var score = 0
        
        // Base points for rating
        score += 10
        
        // Bonus for photo
        if hasPhoto {
            score += 15
        }
        
        // Bonus for detailed ratings
        if creaminessRating != nil { score += 5 }
        if chaiStrengthRating != nil { score += 5 }
        if let notes = flavorNotes, !notes.isEmpty { score += 5 }
        if chaiType != nil { score += 5 }
        
        // Bonus for comment
        if let comment = comment, !comment.isEmpty {
            score += min(comment.count / 10, 10) // Max 10 points for long comments
        }
        
        // Bonus for first review
        if isFirstReview { score += 25 }
        
        // Bonus for new spot
        if isNewSpot { score += 15 }
        
        // Bonus for streak
        if isStreakReview { score += 10 }
        
        return score
    }
}
