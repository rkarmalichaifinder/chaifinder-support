import Foundation
import FirebaseFirestore
import FirebaseAuth

class WeeklyRankingService: ObservableObject {
    private let db = Firestore.firestore()
    private let notificationService = NotificationService.shared
    private let leaderboardViewModel = LeaderboardViewModel()
    
    static let shared = WeeklyRankingService()
    
    private init() {}
    
    // Schedule weekly ranking notification
    func scheduleWeeklyRankingNotification() {
        notificationService.scheduleWeeklyRankingNotification()
    }
    
    // Send weekly ranking notification with current user's ranking
    func sendWeeklyRankingNotification() async {
        guard let ranking = await leaderboardViewModel.getCurrentUserRanking() else {
            print("❌ Could not get user ranking for weekly notification")
            return
        }
        
        notificationService.notifyWeeklyRanking(
            rank: ranking.rank,
            totalUsers: ranking.totalUsers,
            score: ranking.score
        )
    }
    
    // Check if it's time to send weekly ranking notification
    func checkAndSendWeeklyRanking() {
        let calendar = Calendar.current
        let now = Date()
        
        // Check if it's Sunday and after 6 PM
        let weekday = calendar.component(.weekday, from: now)
        let hour = calendar.component(.hour, from: now)
        
        if weekday == 1 && hour >= 18 { // Sunday and 6 PM or later
            Task {
                await sendWeeklyRankingNotification()
            }
        }
    }
    
    // Get last notification date to avoid duplicates
    private func getLastWeeklyRankingNotificationDate() -> Date? {
        if let dateData = UserDefaults.standard.data(forKey: "lastWeeklyRankingNotification"),
           let date = try? JSONDecoder().decode(Date.self, from: dateData) {
            return date
        }
        return nil
    }
    
    // Save last notification date
    private func saveLastWeeklyRankingNotificationDate() {
        let now = Date()
        if let dateData = try? JSONEncoder().encode(now) {
            UserDefaults.standard.set(dateData, forKey: "lastWeeklyRankingNotification")
        }
    }
    
    // Check if we should send notification (avoid duplicates in same week)
    private func shouldSendWeeklyRankingNotification() -> Bool {
        guard let lastNotificationDate = getLastWeeklyRankingNotificationDate() else {
            return true // First time, send notification
        }
        
        let calendar = Calendar.current
        let now = Date()
        
        // Check if it's been at least 7 days since last notification
        let daysSinceLastNotification = calendar.dateComponents([.day], from: lastNotificationDate, to: now).day ?? 0
        
        return daysSinceLastNotification >= 7
    }
    
    // Public method to trigger weekly ranking notification (for testing or manual triggers)
    func triggerWeeklyRankingNotification() async {
        if shouldSendWeeklyRankingNotification() {
            await sendWeeklyRankingNotification()
            saveLastWeeklyRankingNotificationDate()
        }
    }
}
