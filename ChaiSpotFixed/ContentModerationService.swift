import Foundation
import FirebaseFirestore
import FirebaseAuth
import FirebaseCore

class ContentModerationService: ObservableObject {
    private lazy var db: Firestore = {
        // Only create Firestore instance when actually needed
        // Firebase should be configured by SessionStore before this is called
        return Firestore.firestore()
    }()
    
    // Minimum content size before applying heuristic checks like ALL CAPS or excessive punctuation
    private let minimumLettersForHeuristics = 10
    
    // List of objectionable words/phrases to filter
    private let objectionableWords = [
        "fuck", "shit", "bitch", "ass", "damn", "hell", "crap", "piss", "dick", "cock", "pussy", "cunt",
        "faggot", "nigger", "nigga", "spic", "chink", "kike", "wop", "dago", "kraut", "jap", "gook",
        "terrorist", "bomb", "kill", "murder", "suicide", "drugs", "cocaine", "heroin", "marijuana",
        "porn", "sex", "nude", "naked", "penis", "vagina", "boobs", "tits", "asshole", "bastard"
    ]
    
    // MARK: - Content Filtering
    
    func filterContent(_ text: String) -> (isAppropriate: Bool, filteredText: String) {
        let lowercasedText = text.lowercased()
        var filteredText = text
        
        // Check for objectionable words
        for word in objectionableWords {
            if lowercasedText.contains(word) {
                return (false, text) // Return original text but mark as inappropriate
            }
        }
        
        // Check for excessive caps (shouting)
        let uppercaseCount = text.filter { $0.isUppercase }.count
        let totalLetters = text.filter { $0.isLetter }.count
        if totalLetters >= minimumLettersForHeuristics {
            if Double(uppercaseCount) / Double(totalLetters) > 0.7 {
                return (false, text)
            }
        }
        
        // Check for excessive punctuation
        let punctuationCount = text.filter { "!@#$%^&*()_+-=[]{}|;':\",./<>?".contains($0) }.count
        if totalLetters >= minimumLettersForHeuristics {
            if punctuationCount > max(1, text.count / 3) {
                return (false, text)
            }
        }
        
        return (true, filteredText)
    }
    
    // MARK: - Report Content
    
    func reportContent(contentId: String, contentType: ContentType, reason: ReportReason, additionalDetails: String? = nil) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let report = [
            "contentId": contentId,
            "contentType": contentType.rawValue,
            "reportedBy": userId,
            "reason": reason.rawValue,
            "additionalDetails": additionalDetails ?? "",
            "timestamp": FieldValue.serverTimestamp(),
            "status": "pending"
        ] as [String: Any]
        
        db.collection("reports").addDocument(data: report) { error in
            if let error = error {
                print("Error reporting content: \(error.localizedDescription)")
            } else {
                print("Content reported successfully")
            }
        }
    }
    
    // MARK: - Block User
    
    func blockUser(userIdToBlock: String) {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        let blockData = [
            "blockedBy": currentUserId,
            "blockedUser": userIdToBlock,
            "timestamp": FieldValue.serverTimestamp()
        ] as [String: Any]
        
        db.collection("blocks").addDocument(data: blockData) { error in
            if let error = error {
                print("Error blocking user: \(error.localizedDescription)")
            } else {
                print("User blocked successfully")
            }
        }
    }
    
    // MARK: - Check if User is Blocked
    
    func isUserBlocked(userId: String, completion: @escaping (Bool) -> Void) {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            completion(false)
            return
        }
        
        db.collection("blocks")
            .whereField("blockedBy", isEqualTo: currentUserId)
            .whereField("blockedUser", isEqualTo: userId)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error checking block status: \(error.localizedDescription)")
                    completion(false)
                    return
                }
                
                completion(!(snapshot?.documents.isEmpty ?? true))
            }
    }
    
    // MARK: - Get Blocked Users
    
    func getBlockedUsers(completion: @escaping ([String]) -> Void) {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            completion([])
            return
        }
        
        db.collection("blocks")
            .whereField("blockedBy", isEqualTo: currentUserId)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error getting blocked users: \(error.localizedDescription)")
                    completion([])
                    return
                }
                
                let blockedUserIds = snapshot?.documents.compactMap { doc in
                    doc.data()["blockedUser"] as? String
                } ?? []
                
                completion(blockedUserIds)
            }
    }
    
    // MARK: - Unblock User
    
    func unblockUser(userIdToUnblock: String) {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        db.collection("blocks")
            .whereField("blockedBy", isEqualTo: currentUserId)
            .whereField("blockedUser", isEqualTo: userIdToUnblock)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error finding block document: \(error.localizedDescription)")
                    return
                }
                
                for document in snapshot?.documents ?? [] {
                    document.reference.delete { error in
                        if let error = error {
                            print("Error unblocking user: \(error.localizedDescription)")
                        } else {
                            print("User unblocked successfully")
                        }
                    }
                }
            }
    }
    
    // MARK: - Get Reports for Admin
    
    func getReports(completion: @escaping ([Report]) -> Void) {
        db.collection("reports")
            .order(by: "timestamp", descending: true)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error getting reports: \(error.localizedDescription)")
                    completion([])
                    return
                }
                
                let reports = snapshot?.documents.compactMap { doc -> Report? in
                    let data = doc.data()
                    return Report(
                        id: doc.documentID,
                        contentId: data["contentId"] as? String ?? "",
                        contentType: ContentType(rawValue: data["contentType"] as? String ?? "") ?? .rating,
                        reportedBy: data["reportedBy"] as? String ?? "",
                        reason: ReportReason(rawValue: data["reason"] as? String ?? "") ?? .inappropriate,
                        additionalDetails: data["additionalDetails"] as? String ?? "",
                        timestamp: (data["timestamp"] as? Timestamp)?.dateValue() ?? Date(),
                        status: ReportStatus(rawValue: data["status"] as? String ?? "") ?? .pending
                    )
                } ?? []
                
                completion(reports)
            }
    }
    
    // MARK: - Update Report Status
    
    func updateReportStatus(reportId: String, status: ReportStatus, adminNotes: String? = nil) {
        var updateData: [String: Any] = ["status": status.rawValue]
        if let notes = adminNotes {
            updateData["adminNotes"] = notes
        }
        
        db.collection("reports").document(reportId).updateData(updateData) { error in
            if let error = error {
                print("Error updating report status: \(error.localizedDescription)")
            } else {
                print("Report status updated successfully")
            }
        }
    }
}

// MARK: - Supporting Types

enum ContentType: String, CaseIterable {
    case rating = "rating"
    case comment = "comment"
    case spot = "spot"
    case user = "user"
}

enum ReportReason: String, CaseIterable {
    case inappropriate = "inappropriate"
    case spam = "spam"
    case harassment = "harassment"
    case fake = "fake"
    case other = "other"
    
    var displayName: String {
        switch self {
        case .inappropriate: return "Inappropriate Content"
        case .spam: return "Spam"
        case .harassment: return "Harassment"
        case .fake: return "Fake/Misleading"
        case .other: return "Other"
        }
    }
}

enum ReportStatus: String, CaseIterable {
    case pending = "pending"
    case reviewed = "reviewed"
    case resolved = "resolved"
    case dismissed = "dismissed"
    
    var displayName: String {
        switch self {
        case .pending: return "Pending Review"
        case .reviewed: return "Under Review"
        case .resolved: return "Resolved"
        case .dismissed: return "Dismissed"
        }
    }
}

struct Report: Identifiable {
    let id: String
    let contentId: String
    let contentType: ContentType
    let reportedBy: String
    let reason: ReportReason
    let additionalDetails: String
    let timestamp: Date
    let status: ReportStatus
} 