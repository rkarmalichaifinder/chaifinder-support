import Foundation
import Firebase
import FirebaseFirestore
import UserNotifications

// MARK: - Notification Preferences
struct NotificationPreferences: Codable {
    var enabledTypes: Set<FeedItemType> = Set(FeedItemType.allCases)
    var maxNotificationsPerHour: Int = 5
    var maxNotificationsPerDay: Int = 20
    var quietHoursStart: Int = 22 // 10 PM
    var quietHoursEnd: Int = 8    // 8 AM
    var enableSound: Bool = true
    var enableVibration: Bool = true
    var enableBadge: Bool = true
}

// MARK: - Notification Manager
class SmartNotificationManager: ObservableObject {
    static let shared = SmartNotificationManager()
    
    @Published var preferences: NotificationPreferences
    @Published var notificationCount: Int = 0
    @Published var lastNotificationTime: Date?
    
    private var notificationHistory: [Date] = []
    private var pendingNotifications: [FeedItem] = []
    private var notificationTimer: Timer?
    
    private let userDefaults = UserDefaults.standard
    private let preferencesKey = "notificationPreferences"
    private let historyKey = "notificationHistory"
    
    private init() {
        // Load saved preferences
        if let data = userDefaults.data(forKey: preferencesKey),
           let savedPreferences = try? JSONDecoder().decode(NotificationPreferences.self, from: data) {
            self.preferences = savedPreferences
        } else {
            self.preferences = NotificationPreferences()
        }
        
        // Load notification history
        if let historyData = userDefaults.array(forKey: historyKey) as? [Date] {
            self.notificationHistory = historyData
        }
        
        // Clean up old history entries (older than 24 hours)
        cleanupOldHistory()
        
        // Request notification permissions
        requestNotificationPermissions()
    }
    
    // MARK: - Permission Management
    private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                if granted {
                    print("✅ Notification permissions granted")
                } else {
                    print("❌ Notification permissions denied: \(error?.localizedDescription ?? "Unknown error")")
                }
            }
        }
    }
    
    // MARK: - Smart Notification Logic
    func shouldShowNotification(for item: FeedItem) -> Bool {
        // Check if notification type is enabled
        guard preferences.enabledTypes.contains(item.type) else {
            print("🔕 Notification type \(item.type) is disabled")
            return false
        }
        
        // Check quiet hours
        if isInQuietHours() {
            print("🔕 In quiet hours, skipping notification")
            return false
        }
        
        // Check hourly limit
        if getNotificationCountInLastHour() >= preferences.maxNotificationsPerHour {
            print("🔕 Hourly limit reached (\(preferences.maxNotificationsPerHour))")
            return false
        }
        
        // Check daily limit
        if getNotificationCountInLastDay() >= preferences.maxNotificationsPerDay {
            print("🔕 Daily limit reached (\(preferences.maxNotificationsPerDay))")
            return false
        }
        
        // Check if this is a duplicate notification (same user, same type, within 5 minutes)
        if isDuplicateNotification(for: item) {
            print("🔕 Duplicate notification detected, skipping")
            return false
        }
        
        return true
    }
    
    private func isInQuietHours() -> Bool {
        let calendar = Calendar.current
        let now = Date()
        let hour = calendar.component(.hour, from: now)
        
        if preferences.quietHoursStart < preferences.quietHoursEnd {
            // Same day quiet hours (e.g., 10 PM to 8 AM)
            return hour >= preferences.quietHoursStart || hour < preferences.quietHoursEnd
        } else {
            // Overnight quiet hours (e.g., 10 PM to 8 AM)
            return hour >= preferences.quietHoursStart && hour < preferences.quietHoursEnd
        }
    }
    
    private func getNotificationCountInLastHour() -> Int {
        let oneHourAgo = Date().addingTimeInterval(-3600)
        return notificationHistory.filter { $0 > oneHourAgo }.count
    }
    
    private func getNotificationCountInLastDay() -> Int {
        let oneDayAgo = Date().addingTimeInterval(-86400)
        return notificationHistory.filter { $0 > oneDayAgo }.count
    }
    
    private func isDuplicateNotification(for item: FeedItem) -> Bool {
        let fiveMinutesAgo = Date().addingTimeInterval(-300)
        return notificationHistory.contains { date in
            date > fiveMinutesAgo
        }
    }
    
    // MARK: - Notification Display
    func showNotification(for item: FeedItem) {
        guard shouldShowNotification(for: item) else {
            // Add to pending notifications for later
            pendingNotifications.append(item)
            return
        }
        
        // Record the notification
        recordNotification()
        
        // Create and schedule the notification
        let content = createNotificationContent(for: item)
        let request = UNNotificationRequest(
            identifier: "chai-finder-\(item.id)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to schedule notification: \(error.localizedDescription)")
            } else {
                print("✅ Notification scheduled for \(item.type)")
            }
        }
    }
    
    private func createNotificationContent(for item: FeedItem) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        
        switch item.type {
        case .newUser:
            content.title = "New Chai Enthusiast! 🫖"
            content.body = "\(item.username) just joined chai finder"
            content.sound = preferences.enableSound ? .default : nil
            
        case .newSpot:
            if let spotItem = item as? NewSpotFeedItem {
                content.title = "New Chai Spot Discovered! 📍"
                content.body = "\(item.username) added \(spotItem.spotName)"
                content.sound = preferences.enableSound ? .default : nil
            }
            
        case .achievement:
            if let achievementItem = item as? AchievementFeedItem {
                content.title = "Achievement Unlocked! 🏆"
                content.body = "\(item.username) earned \(achievementItem.achievementName)"
                content.sound = preferences.enableSound ? .default : nil
            }
            
        case .friendActivity:
            content.title = "Friend Activity! 👥"
            content.body = item.username + " " + ((item as? FriendActivityFeedItem)?.activityDescription ?? "did something new")
            content.sound = preferences.enableSound ? .default : nil
            
        case .weeklyChallenge:
            if let challengeItem = item as? WeeklyChallengeFeedItem {
                content.title = "Weekly Challenge Update! 🔥"
                content.body = "\(item.username) is \(challengeItem.progress)/\(challengeItem.target) on \(challengeItem.challengeName)"
                content.sound = preferences.enableSound ? .default : nil
            }
            
        case .review:
            content.title = "New Review! ⭐"
            content.body = "\(item.username) reviewed a chai spot"
            content.sound = preferences.enableSound ? .default : nil
        case .weeklyRanking:
            content.title = "Weekly Ranking! 🏆"
            content.body = "Check your weekly leaderboard ranking"
            content.sound = preferences.enableSound ? .default : nil
        }
        
        content.badge = preferences.enableBadge ? NSNumber(value: getNotificationCountInLastDay()) : nil
        
        return content
    }
    
    // MARK: - History Management
    private func recordNotification() {
        let now = Date()
        notificationHistory.append(now)
        lastNotificationTime = now
        notificationCount += 1
        
        // Save to UserDefaults
        userDefaults.set(notificationHistory, forKey: historyKey)
        
        // Clean up old entries periodically
        if notificationCount % 10 == 0 {
            cleanupOldHistory()
        }
    }
    
    private func cleanupOldHistory() {
        let oneDayAgo = Date().addingTimeInterval(-86400)
        notificationHistory = notificationHistory.filter { $0 > oneDayAgo }
        userDefaults.set(notificationHistory, forKey: historyKey)
    }
    
    // MARK: - Pending Notifications
    func processPendingNotifications() {
        let currentPending = pendingNotifications
        pendingNotifications.removeAll()
        
        for item in currentPending {
            if shouldShowNotification(for: item) {
                showNotification(for: item)
            }
        }
    }
    
    // MARK: - Preferences Management
    func updatePreferences(_ newPreferences: NotificationPreferences) {
        preferences = newPreferences
        
        // Save to UserDefaults
        if let data = try? JSONEncoder().encode(preferences) {
            userDefaults.set(data, forKey: preferencesKey)
        }
    }
    
    func resetNotificationCount() {
        notificationCount = 0
        notificationHistory.removeAll()
        userDefaults.removeObject(forKey: historyKey)
    }
    
    // MARK: - Batch Processing
    func processBatchNotifications(_ items: [FeedItem]) {
        // Sort by timestamp (newest first)
        let sortedItems = items.sorted { $0.timestamp > $1.timestamp }
        
        // Process only the most recent items that fit within limits
        var processedCount = 0
        let maxToProcess = min(preferences.maxNotificationsPerHour, 3) // Limit batch size
        
        for item in sortedItems {
            if processedCount >= maxToProcess {
                break
            }
            
            if shouldShowNotification(for: item) {
                showNotification(for: item)
                processedCount += 1
            }
        }
        
        // Schedule processing of remaining items
        if !pendingNotifications.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 300) { // 5 minutes
                self.processPendingNotifications()
            }
        }
    }
}
