import Foundation
import SwiftUI
import FirebaseFirestore
import FirebaseAuth

class RecommendationEngine: ObservableObject {
    @Published var recommendedSpots: [ChaiSpot] = []
    @Published var isLoading = false
    @Published var recommendationReason: String = ""
    
    private let db = Firestore.firestore()
    private let auth = Auth.auth()
    
    // 🎯 Recommendation types
    enum RecommendationType: String, CaseIterable {
        case personality = "personality"
        case taste = "taste"
        case social = "social"
        case trending = "trending"
        case nearby = "nearby"
        
        var displayName: String {
            switch self {
            case .personality: return "Based on your personality"
            case .taste: return "Based on your taste preferences"
            case .social: return "Loved by your friends"
            case .trending: return "Trending in your area"
            case .nearby: return "Nearby spots you haven't tried"
            }
        }
        
        var iconName: String {
            switch self {
            case .personality: return "person.fill"
            case .taste: return "heart.fill"
            case .social: return "person.2.fill"
            case .trending: return "flame.fill"
            case .nearby: return "location.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .personality: return .orange
            case .taste: return .red
            case .social: return .blue
            case .trending: return .purple
            case .nearby: return .green
            }
        }
    }
    
    // 🫖 Recommendation result
    struct RecommendationResult {
        let spot: ChaiSpot
        let type: RecommendationType
        let score: Double
        let reason: String
        let confidence: Double
    }
    
    init() {
        loadRecommendations()
    }
    
    // 🎯 Load personalized recommendations
    func loadRecommendations() {
        guard let userId = auth.currentUser?.uid else { return }
        
        isLoading = true
        
        Task {
            let recommendations = await generatePersonalizedRecommendations(for: userId)
            
            await MainActor.run {
                self.recommendedSpots = recommendations.map { $0.spot }
                self.isLoading = false
            }
        }
    }
    
    // 🔮 Generate personalized recommendations
    private func generatePersonalizedRecommendations(for userId: String) async -> [RecommendationResult] {
        var allRecommendations: [RecommendationResult] = []
        
        // Get user profile and preferences
        guard let userProfile = await getUserProfile(userId: userId) else {
            return []
        }
        
        // Get all chai spots
        let allSpots = await getAllChaiSpots()
        
        // Get user's visited spots
        let visitedSpotIds = await getVisitedSpotIds(for: userId)
        
        // Filter out already visited spots
        let unvisitedSpots = allSpots.filter { !visitedSpotIds.contains($0.id ?? "") }
        
        // Generate recommendations for each type
        let tasteRecs = await generateTasteRecommendations(
            spots: unvisitedSpots,
            userProfile: userProfile
        )
        
        let socialRecs = await generateSocialRecommendations(
            spots: unvisitedSpots,
            userProfile: userProfile,
            userId: userId
        )
        
        let trendingRecs = await generateTrendingRecommendations(
            spots: unvisitedSpots
        )
        
        let nearbyRecs = await generateNearbyRecommendations(
            spots: unvisitedSpots,
            userProfile: userProfile
        )
        
        // Combine and sort by score
        allRecommendations.append(contentsOf: tasteRecs)
        allRecommendations.append(contentsOf: socialRecs)
        allRecommendations.append(contentsOf: trendingRecs)
        allRecommendations.append(contentsOf: nearbyRecs)
        
        // Sort by score and remove duplicates
        let sortedRecommendations = allRecommendations
            .sorted { $0.score > $1.score }
        
        // Remove duplicates based on spot ID
        var seenSpotIds = Set<String>()
        var uniqueRecommendations: [RecommendationResult] = []
        
        for recommendation in sortedRecommendations {
            if !seenSpotIds.contains(recommendation.spot.id) {
                seenSpotIds.insert(recommendation.spot.id)
                uniqueRecommendations.append(recommendation)
            }
        }
        
        // Return top recommendations
        return Array(uniqueRecommendations.prefix(10))
    }
    

    
    // 🎯 Taste-based recommendations
    private func generateTasteRecommendations(
        spots: [ChaiSpot],
        userProfile: UserProfile
    ) async -> [RecommendationResult] {
        guard let tasteVector = userProfile.tasteVector,
              tasteVector.count >= 2 else {
            return []
        }
        
        let creaminess = tasteVector[0]
        let strength = tasteVector[1]
        
        var recommendations: [RecommendationResult] = []
        
        for spot in spots {
            let score = calculateTasteScore(
                spot: spot,
                preferredCreaminess: creaminess,
                preferredStrength: strength
            )
            
            if score > 0.4 {
                let reason = generateTasteReason(
                    creaminess: creaminess,
                    strength: strength,
                    spot: spot
                )
                let confidence = min(score * 1.5, 1.0)
                
                let recommendation = RecommendationResult(
                    spot: spot,
                    type: .taste,
                    score: score,
                    reason: reason,
                    confidence: confidence
                )
                
                recommendations.append(recommendation)
            }
        }
        
        return recommendations.sorted { $0.score > $1.score }
    }
    
    // 👥 Social recommendations
    private func generateSocialRecommendations(
        spots: [ChaiSpot],
        userProfile: UserProfile,
        userId: String
    ) async -> [RecommendationResult] {
        guard let friends = userProfile.friends, !friends.isEmpty else {
            return []
        }
        
        var recommendations: [RecommendationResult] = []
        
        for spot in spots {
            let score = await calculateSocialScore(
                spot: spot,
                friends: friends,
                userId: userId
            )
            
            if score > 0.2 {
                let reason = generateSocialReason(spot: spot, score: score)
                let confidence = min(score * 2, 1.0)
                
                let recommendation = RecommendationResult(
                    spot: spot,
                    type: .social,
                    score: score,
                    reason: reason,
                    confidence: confidence
                )
                
                recommendations.append(recommendation)
            }
        }
        
        return recommendations.sorted { $0.score > $1.score }
    }
    
    // 🔥 Trending recommendations
    private func generateTrendingRecommendations(spots: [ChaiSpot]) async -> [RecommendationResult] {
        var recommendations: [RecommendationResult] = []
        
        for spot in spots {
            let score = await calculateTrendingScore(spot: spot)
            
            if score > 0.3 {
                let reason = generateTrendingReason(score: score)
                let confidence = min(score * 1.5, 1.0)
                
                let recommendation = RecommendationResult(
                    spot: spot,
                    type: .trending,
                    score: score,
                    reason: reason,
                    confidence: confidence
                )
                
                recommendations.append(recommendation)
            }
        }
        
        return recommendations.sorted { $0.score > $1.score }
    }
    
    // 📍 Nearby recommendations
    private func generateNearbyRecommendations(
        spots: [ChaiSpot],
        userProfile: UserProfile
    ) async -> [RecommendationResult] {
        // For now, we'll use a simple approach
        // In a real app, you'd use Core Location and calculate actual distances
        
        var recommendations: [RecommendationResult] = []
        
        for (index, spot) in spots.enumerated() {
            let score = 1.0 / Double(index + 1) // Simple ranking
            let reason = "New spot in your area"
            let confidence = 0.6
            
            let recommendation = RecommendationResult(
                spot: spot,
                type: .nearby,
                score: score,
                reason: reason,
                confidence: confidence
            )
            
            recommendations.append(recommendation)
        }
        
        return recommendations.sorted { $0.score > $1.score }
    }
    

    
    // 🎯 Calculate taste score
    private func calculateTasteScore(
        spot: ChaiSpot,
        preferredCreaminess: Int,
        preferredStrength: Int
    ) -> Double {
        var score = 0.0
        
        // This is a simplified scoring system
        // In a real app, you'd analyze actual ratings and reviews
        
        // Base score
        score += 0.3
        
        // Add some randomness for variety
        score += Double.random(in: 0...0.3)
        
        return min(score, 1.0)
    }
    
    // 👥 Calculate social score
    private func calculateSocialScore(
        spot: ChaiSpot,
        friends: [String],
        userId: String
    ) async -> Double {
        var totalScore = 0.0
        var friendCount = 0
        
        for friendId in friends {
            // Check if friend has rated this spot
            let friendRating = await getFriendRating(spotId: spot.id, friendId: friendId)
            
            if let rating = friendRating {
                totalScore += Double(rating.value) / 5.0
                friendCount += 1
            }
        }
        
        if friendCount == 0 {
            return 0.0
        }
        
        return totalScore / Double(friendCount)
    }
    
    // 🔥 Calculate trending score
    private func calculateTrendingScore(spot: ChaiSpot) async -> Double {
        // Get recent reviews for this spot
        let recentReviews = await getRecentReviews(for: spot.id)
        
        let reviewCount = recentReviews.count
        let averageRating = recentReviews.map { Double($0.value) }.reduce(0, +) / max(Double(reviewCount), 1)
        
        // Simple trending algorithm: recent activity + high ratings
        let trendingScore = (Double(reviewCount) * 0.1) + (averageRating * 0.2)
        
        return min(trendingScore, 1.0)
    }
    

    
    private func generateTasteReason(
        creaminess: Int,
        strength: Int,
        spot: ChaiSpot
    ) -> String {
        return "Matches your taste preferences perfectly!"
    }
    
    private func generateSocialReason(spot: ChaiSpot, score: Double) -> String {
        if score > 0.8 {
            return "Loved by your friends!"
        } else if score > 0.6 {
            return "Highly rated by your friends!"
        } else {
            return "Recommended by your friends!"
        }
    }
    
    private func generateTrendingReason(score: Double) -> String {
        if score > 0.8 {
            return "🔥 Hot right now!"
        } else if score > 0.6 {
            return "📈 Trending in your area!"
        } else {
            return "🌟 Popular spot!"
        }
    }
    
    // 🔍 Helper functions
    private func getUserProfile(userId: String) async -> UserProfile? {
        do {
            let document = try await db.collection("users").document(userId).getDocument()
            guard let data = document.data() else { return nil }
            
            let id = data["id"] as? String ?? userId
            let displayName = data["displayName"] as? String ?? "Unknown User"
            let email = data["email"] as? String ?? ""
            let bio = data["bio"] as? String
            let photoURL = data["photoURL"] as? String
            let friends = data["friends"] as? [String] ?? []

            let tasteVector = data["tasteVector"] as? [Double]
            let totalScore = data["totalScore"] as? Int ?? 0
            let currentStreak = data["currentStreak"] as? Int ?? 0
            let longestStreak = data["longestStreak"] as? Int ?? 0
            let badges = data["badges"] as? [String] ?? []
            let achievements = data["achievements"] as? [String] ?? []
            let hasAcceptedTerms = data["hasAcceptedTerms"] as? Bool ?? false
            let privacyDefaults = data["privacyDefaults"] as? [String: Any]
            
            return UserProfile(
                id: id,
                uid: userId,
                displayName: displayName,
                email: email,
                photoURL: photoURL,
                friends: friends,
                incomingRequests: [],
                outgoingRequests: [],
                bio: bio,
                hasTasteSetup: false,
                tasteVector: tasteVector?.map { Int($0) },
                topTasteTags: nil,
                privacyDefaults: PrivacyDefaults(),
                badges: badges,
                currentStreak: currentStreak,
                longestStreak: longestStreak,
                lastReviewDate: nil,

                totalReviews: 0,
                spotsVisited: 0,
                challengeProgress: [:],
                achievements: Dictionary(uniqueKeysWithValues: achievements.map { ($0, Date()) }),
                totalScore: totalScore
            )
        } catch {
            print("Error fetching user profile: \(error)")
            return nil
        }
    }
    
    private func getAllChaiSpots() async -> [ChaiSpot] {
        do {
            let snapshot = try await db.collection("chaiFinder").getDocuments()
            return snapshot.documents.compactMap { document in
                let data = document.data()
                let id = data["id"] as? String ?? document.documentID
                let name = data["name"] as? String ?? "Unknown Spot"
                let address = data["address"] as? String ?? "Unknown Address"
                let latitude = data["latitude"] as? Double ?? 0.0
                let longitude = data["longitude"] as? Double ?? 0.0
                let chaiTypes = data["chaiTypes"] as? [String] ?? []
                let averageRating = data["averageRating"] as? Double ?? 0.0
                let ratingCount = data["ratingCount"] as? Int ?? 0
                
                return ChaiSpot(
                    id: id,
                    name: name,
                    address: address,
                    latitude: latitude,
                    longitude: longitude,
                    chaiTypes: chaiTypes,
                    averageRating: averageRating,
                    ratingCount: ratingCount
                )
            }
        } catch {
            print("Error fetching chai spots: \(error)")
            return []
        }
    }
    
    private func getVisitedSpotIds(for userId: String) async -> Set<String> {
        do {
            let snapshot = try await db.collection("ratings")
                .whereField("userId", isEqualTo: userId)
                .getDocuments()
            
            return Set(snapshot.documents.compactMap { $0.data()["spotId"] as? String })
        } catch {
            print("Error fetching visited spots: \(error)")
            return []
        }
    }
    
    private func getFriendRating(spotId: String, friendId: String) async -> Rating? {
        do {
            let snapshot = try await db.collection("ratings")
                .whereField("spotId", isEqualTo: spotId)
                .whereField("userId", isEqualTo: friendId)
                .getDocuments()
            
            guard let document = snapshot.documents.first else { return nil }
            let data = document.data()
            
            let id = document.documentID
            let userId = data["userId"] as? String ?? ""
            let username = data["username"] as? String ?? "Anonymous"
            let spotName = data["spotName"] as? String
            let value = data["value"] as? Int ?? 0
            let comment = data["comment"] as? String
            let timestamp = data["timestamp"] as? Timestamp
            let likes = data["likes"] as? Int
            let dislikes = data["dislikes"] as? Int
            let creaminessRating = data["creaminessRating"] as? Int
            let chaiStrengthRating = data["chaiStrengthRating"] as? Int
            let flavorNotes = data["flavorNotes"] as? [String]
            let chaiType = data["chaiType"] as? String
            let photoURL = data["photoURL"] as? String
            let hasPhoto = data["hasPhoto"] as? Bool ?? false
            let reactions = data["reactions"] as? [String: Int] ?? [:]
            let isStreakReview = data["isStreakReview"] as? Bool ?? false
            let gamificationScore = data["gamificationScore"] as? Int ?? 0
            let isFirstReview = data["isFirstReview"] as? Bool ?? false
            let isNewSpot = data["isNewSpot"] as? Bool ?? false
            
            return Rating(
                id: id,
                spotId: spotId,
                userId: userId,
                username: username,
                spotName: spotName,
                value: value,
                comment: comment,
                timestamp: timestamp?.dateValue(),
                likes: likes,
                dislikes: dislikes,
                creaminessRating: creaminessRating,
                chaiStrengthRating: chaiStrengthRating,
                flavorNotes: flavorNotes,
                chaiType: chaiType,
                photoURL: photoURL,
                hasPhoto: hasPhoto,
                reactions: reactions,
                isStreakReview: isStreakReview,
                gamificationScore: gamificationScore,
                isFirstReview: isFirstReview,
                isNewSpot: isNewSpot
            )
        } catch {
            print("Error fetching friend rating: \(error)")
            return nil
        }
    }
    
    private func getRecentReviews(for spotId: String) async -> [Rating] {
        let calendar = Calendar.current
        let oneWeekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        
        do {
            let snapshot = try await db.collection("ratings")
                .whereField("spotId", isEqualTo: spotId)
                .whereField("timestamp", isGreaterThan: oneWeekAgo)
                .getDocuments()
            
            return snapshot.documents.compactMap { document in
                let data = document.data()
                
                let id = document.documentID
                let userId = data["userId"] as? String ?? ""
                let username = data["username"] as? String ?? "Anonymous"
                let spotName = data["spotName"] as? String
                let value = data["value"] as? Int ?? 0
                let comment = data["comment"] as? String
                let timestamp = data["timestamp"] as? Timestamp
                let likes = data["likes"] as? Int
                let dislikes = data["dislikes"] as? Int
                let creaminessRating = data["creaminessRating"] as? Int
                let chaiStrengthRating = data["chaiStrengthRating"] as? Int
                let flavorNotes = data["flavorNotes"] as? [String]
                let chaiType = data["chaiType"] as? String
                let photoURL = data["photoURL"] as? String
                let hasPhoto = data["hasPhoto"] as? Bool ?? false
                let reactions = data["reactions"] as? [String: Int] ?? [:]
                let isStreakReview = data["isStreakReview"] as? Bool ?? false
                let gamificationScore = data["gamificationScore"] as? Int ?? 0
                let isFirstReview = data["isFirstReview"] as? Bool ?? false
                let isNewSpot = data["isNewSpot"] as? Bool ?? false
                
                return Rating(
                    id: id,
                    spotId: spotId,
                    userId: userId,
                    username: username,
                    spotName: spotName,
                    value: value,
                    comment: comment,
                    timestamp: timestamp?.dateValue(),
                    likes: likes,
                    dislikes: dislikes,
                    creaminessRating: creaminessRating,
                    chaiStrengthRating: chaiStrengthRating,
                    flavorNotes: flavorNotes,
                    chaiType: chaiType,
                    photoURL: photoURL,
                    hasPhoto: hasPhoto,
                    reactions: reactions,
                    isStreakReview: isStreakReview,
                    gamificationScore: gamificationScore,
                    isFirstReview: isFirstReview,
                    isNewSpot: isNewSpot
                )
            }
        } catch {
            print("Error fetching recent reviews: \(error)")
            return []
        }
    }
    
    // 🔄 Refresh recommendations
    func refreshRecommendations() {
        loadRecommendations()
    }
}

// 🔧 Array extension for removing duplicates
extension Array where Element: Hashable {
    func uniqued<T: Hashable>(by keyPath: KeyPath<Element, T>) -> [Element] {
        var seen = Set<T>()
        return filter { element in
            let key = element[keyPath: keyPath]
            if seen.contains(key) {
                return false
            } else {
                seen.insert(key)
                return true
            }
        }
    }
}
