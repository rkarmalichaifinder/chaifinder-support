import Foundation
import Firebase
import FirebaseAuth
import FirebaseMessaging
import UserNotifications
import SwiftUI

class NotificationService: NSObject, ObservableObject {
    @Published var isNotificationsEnabled = false
    @Published var fcmToken: String?
    
    // User notification preferences
    @Published var badgeNotifications = true
    @Published var achievementNotifications = true
    @Published var streakNotifications = true
    @Published var weeklyChallengeNotifications = true
    @Published var friendActivityNotifications = true
    @Published var friendRequestNotifications = true
    
    // Notification timing preferences
    @Published var quietHoursEnabled = false
    @Published var quietHoursStart = Calendar.current.date(from: DateComponents(hour: 22, minute: 0)) ?? Date()
    @Published var quietHoursEnd = Calendar.current.date(from: DateComponents(hour: 8, minute: 0)) ?? Date()
    
    // Notification frequency preferences
    @Published var digestNotifications = false
    @Published var digestTime = Calendar.current.date(from: DateComponents(hour: 18, minute: 0)) ?? Date()
    
    // Pending notifications for digest mode
    private var pendingNotifications: [String] = []
    
    static let shared = NotificationService()
    
    override init() {
        super.init()
        loadNotificationPreferences()
        setupNotifications()
    }
    
    // MARK: - User Preferences
    
    private func loadNotificationPreferences() {
        badgeNotifications = UserDefaults.standard.bool(forKey: "notifications.badges")
        achievementNotifications = UserDefaults.standard.bool(forKey: "notifications.achievements")
        streakNotifications = UserDefaults.standard.bool(forKey: "notifications.streaks")
        weeklyChallengeNotifications = UserDefaults.standard.bool(forKey: "notifications.weeklyChallenges")
        friendActivityNotifications = UserDefaults.standard.bool(forKey: "notifications.friendActivity")
        friendRequestNotifications = UserDefaults.standard.bool(forKey: "notifications.friendRequests")
        
        // Load quiet hours preferences
        quietHoursEnabled = UserDefaults.standard.bool(forKey: "notifications.quietHoursEnabled")
        if let startData = UserDefaults.standard.data(forKey: "notifications.quietHoursStart"),
           let startDate = try? JSONDecoder().decode(Date.self, from: startData) {
            quietHoursStart = startDate
        }
        if let endData = UserDefaults.standard.data(forKey: "notifications.quietHoursEnd"),
           let endDate = try? JSONDecoder().decode(Date.self, from: endData) {
            quietHoursEnd = endDate
        }
        
        // Load digest preferences
        digestNotifications = UserDefaults.standard.bool(forKey: "notifications.digestEnabled")
        if let timeData = UserDefaults.standard.data(forKey: "notifications.digestTime"),
           let time = try? JSONDecoder().decode(Date.self, from: timeData) {
            digestTime = time
        }
        
        // Set defaults if no preferences exist
        if UserDefaults.standard.object(forKey: "notifications.badges") == nil {
            badgeNotifications = true
            UserDefaults.standard.set(true, forKey: "notifications.badges")
        }
        if UserDefaults.standard.object(forKey: "notifications.achievements") == nil {
            achievementNotifications = true
            UserDefaults.standard.set(true, forKey: "notifications.achievements")
        }
        if UserDefaults.standard.object(forKey: "notifications.streaks") == nil {
            streakNotifications = true
            UserDefaults.standard.set(true, forKey: "notifications.streaks")
        }
        if UserDefaults.standard.object(forKey: "notifications.weeklyChallenges") == nil {
            weeklyChallengeNotifications = true
            UserDefaults.standard.set(true, forKey: "notifications.weeklyChallenges")
        }
        if UserDefaults.standard.object(forKey: "notifications.friendActivity") == nil {
            friendActivityNotifications = true
            UserDefaults.standard.set(true, forKey: "notifications.friendActivity")
        }
        if UserDefaults.standard.object(forKey: "notifications.friendRequests") == nil {
            friendRequestNotifications = true
            UserDefaults.standard.set(true, forKey: "notifications.friendRequests")
        }
    }
    
    func updateNotificationPreference(type: NotificationPreferenceType, enabled: Bool) {
        switch type {
        case .badges:
            badgeNotifications = enabled
            UserDefaults.standard.set(enabled, forKey: "notifications.badges")
        case .achievements:
            achievementNotifications = enabled
            UserDefaults.standard.set(enabled, forKey: "notifications.achievements")
        case .streaks:
            streakNotifications = enabled
            UserDefaults.standard.set(enabled, forKey: "notifications.streaks")
        case .weeklyChallenges:
            weeklyChallengeNotifications = enabled
            UserDefaults.standard.set(enabled, forKey: "notifications.weeklyChallenges")
        case .friendActivity:
            friendActivityNotifications = enabled
            UserDefaults.standard.set(enabled, forKey: "notifications.friendActivity")
        case .friendRequests:
            friendRequestNotifications = enabled
            UserDefaults.standard.set(enabled, forKey: "notifications.friendRequests")
        }
    }
    
    func resetNotificationPreferences() {
        let defaultPreferences: [NotificationPreferenceType: Bool] = [
            .badges: true,
            .achievements: true,
            .streaks: true,
            .weeklyChallenges: true,
            .friendActivity: true,
            .friendRequests: true
        ]
        
        for (type, enabled) in defaultPreferences {
            updateNotificationPreference(type: type, enabled: enabled)
        }
    }
    
    // Check if any specific notification types are enabled
    var hasAnyNotificationsEnabled: Bool {
        return badgeNotifications || achievementNotifications || streakNotifications || 
               weeklyChallengeNotifications || friendActivityNotifications || friendRequestNotifications
    }
    
    // Get count of enabled notification types
    var enabledNotificationCount: Int {
        var count = 0
        if badgeNotifications { count += 1 }
        if achievementNotifications { count += 1 }
        if streakNotifications { count += 1 }
        if weeklyChallengeNotifications { count += 1 }
        if friendActivityNotifications { count += 1 }
        if friendRequestNotifications { count += 1 }
        return count
    }
    
    // Check if we're currently in quiet hours
    private var isInQuietHours: Bool {
        guard quietHoursEnabled else { return false }
        
        let now = Date()
        let calendar = Calendar.current
        
        // Get current time components
        let currentHour = calendar.component(.hour, from: now)
        let currentMinute = calendar.component(.minute, from: now)
        let currentTime = currentHour * 60 + currentMinute
        
        // Get quiet hours time components
        let startHour = calendar.component(.hour, from: quietHoursStart)
        let startMinute = calendar.component(.minute, from: quietHoursStart)
        let startTime = startHour * 60 + startMinute
        
        let endHour = calendar.component(.hour, from: quietHoursEnd)
        let endMinute = calendar.component(.minute, from: quietHoursEnd)
        let endTime = endHour * 60 + endMinute
        
        // Handle overnight quiet hours (e.g., 10 PM to 8 AM)
        if startTime > endTime {
            // Overnight: current time should be >= start OR <= end
            return currentTime >= startTime || currentTime <= endTime
        } else {
            // Same day: current time should be >= start AND <= end
            return currentTime >= startTime && currentTime <= endTime
        }
    }
    
    // Check if we should send digest notifications instead of individual ones
    private var shouldSendDigest: Bool {
        return digestNotifications && !isInQuietHours
    }
    
    // Update quiet hours settings
    func updateQuietHours(enabled: Bool, start: Date, end: Date) {
        quietHoursEnabled = enabled
        quietHoursStart = start
        quietHoursEnd = end
        
        // Save to UserDefaults
        UserDefaults.standard.set(enabled, forKey: "notifications.quietHoursEnabled")
        if let startData = try? JSONEncoder().encode(start) {
            UserDefaults.standard.set(startData, forKey: "notifications.quietHoursStart")
        }
        if let endData = try? JSONEncoder().encode(end) {
            UserDefaults.standard.set(endData, forKey: "notifications.quietHoursEnd")
        }
    }
    
    // Update digest notification settings
    func updateDigestSettings(enabled: Bool, time: Date) {
        digestNotifications = enabled
        digestTime = time
        
        // Save to UserDefaults
        UserDefaults.standard.set(enabled, forKey: "notifications.digestEnabled")
        if let timeData = try? JSONEncoder().encode(time) {
            UserDefaults.standard.set(timeData, forKey: "notifications.digestTime")
        }
        
        if enabled {
            scheduleDigestNotification()
        } else {
            cancelDigestNotification()
        }
    }
    
    // Schedule daily digest notification
    private func scheduleDigestNotification() {
        let content = UNMutableNotificationContent()
        content.title = "📰 Your Daily Chai Digest"
        content.body = "Tap to see what's new in your chai community"
        content.sound = .default
        
        let calendar = Calendar.current
        var dateComponents = calendar.dateComponents([.hour, .minute], from: digestTime)
        dateComponents.second = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: "daily_digest",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Error scheduling digest notification: \(error.localizedDescription)")
            } else {
                print("✅ Daily digest notification scheduled for \(dateComponents.hour ?? 0):\(dateComponents.minute ?? 0)")
            }
        }
    }
    
    // Cancel digest notification
    private func cancelDigestNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["daily_digest"])
    }
    
    // Add notification to pending queue for digest mode
    private func addToPendingQueue(_ notificationText: String) {
        pendingNotifications.append(notificationText)
        
        // Limit pending notifications to prevent memory issues
        if pendingNotifications.count > 20 {
            pendingNotifications.removeFirst(pendingNotifications.count - 20)
        }
    }
    
    // Send digest notification with all pending notifications
    private func sendDigestNotification() {
        guard !pendingNotifications.isEmpty else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "📰 Your Chai Digest"
        content.body = pendingNotifications.joined(separator: "\n")
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1.0, repeats: false)
        let request = UNNotificationRequest(
            identifier: "digest_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Error sending digest notification: \(error.localizedDescription)")
            } else {
                print("✅ Digest notification sent with \(self.pendingNotifications.count) items")
                self.pendingNotifications.removeAll()
            }
        }
    }
    
    // Public method to manually trigger digest notification (for testing)
    func triggerDigestNotification() {
        sendDigestNotification()
    }
    
    // Get count of pending notifications
    var pendingNotificationCount: Int {
        return pendingNotifications.count
    }
    
    // MARK: - Setup
    func setupNotifications() {
        // Request notification permissions
        UNUserNotificationCenter.current().delegate = self
        
        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
        UNUserNotificationCenter.current().requestAuthorization(
            options: authOptions,
            completionHandler: { [weak self] granted, error in
                DispatchQueue.main.async {
                    self?.isNotificationsEnabled = granted
                    if granted {
                        self?.registerForRemoteNotifications()
                    }
                }
                
                if let error = error {
                    print("❌ Notification permission error: \(error.localizedDescription)")
                }
            }
        )
        
        // Set messaging delegate
        Messaging.messaging().delegate = self
    }
    
    // MARK: - Remote Notifications
    func registerForRemoteNotifications() {
        DispatchQueue.main.async {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
        print("✅ APNS token set successfully")
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("❌ Failed to register for remote notifications: \(error.localizedDescription)")
    }
    
    // MARK: - Gamification Notifications
    func scheduleGamificationNotification(type: GamificationNotificationType, delay: TimeInterval = 1.0) {
        // Check if this type of notification is enabled
        let isEnabled: Bool
        switch type {
        case .badgeUnlock:
            isEnabled = badgeNotifications
        case .achievementUnlock:
            isEnabled = achievementNotifications
        case .streakMilestone:
            isEnabled = streakNotifications
        case .weeklyChallenge:
            isEnabled = weeklyChallengeNotifications
        case .friendActivity:
            isEnabled = friendActivityNotifications
        }
        
        guard isEnabled else { return }
        
        // Check if we're in quiet hours
        guard !isInQuietHours else { return }
        
        let content = UNMutableNotificationContent()
        content.title = type.title
        content.body = type.body
        content.sound = .default
        content.badge = 1
        
        // Add custom data for gamification
        content.userInfo = [
            "type": type.rawValue,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        let request = UNNotificationRequest(identifier: type.identifier, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Error scheduling notification: \(error.localizedDescription)")
            } else {
                print("✅ Gamification notification scheduled: \(type.title)")
            }
        }
    }
    
    // MARK: - Badge Unlock Notifications
    func notifyBadgeUnlocked(badge: Badge) {
        // Check if badge notifications are enabled
        guard badgeNotifications else { return }
        
        // Check if we're in quiet hours
        guard !isInQuietHours else { return }
        
        // Check if we should send digest notifications
        if shouldSendDigest {
            addToPendingQueue("🎖️ New Badge: \(badge.name)")
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = "🎖️ New Badge Unlocked!"
        content.body = "Congratulations! You've earned the '\(badge.name)' badge!"
        content.sound = .default
        content.badge = 1
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1.0, repeats: false)
        let request = UNNotificationRequest(
            identifier: "badge_\(badge.id)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    // MARK: - Achievement Notifications
    func notifyAchievementUnlocked(achievement: Achievement) {
        // Check if achievement notifications are enabled
        guard achievementNotifications else { return }
        
        // Check if we're in quiet hours
        guard !isInQuietHours else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "🏆 Achievement Unlocked!"
        content.body = "\(achievement.name): \(achievement.description) (+\(achievement.points) points)"
        content.sound = .default
        content.badge = 1
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1.0, repeats: false)
        let request = UNNotificationRequest(
            identifier: "achievement_\(achievement.id)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    // MARK: - Streak Notifications
    func scheduleStreakReminder() {
        // Check if streak notifications are enabled
        guard streakNotifications else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "🔥 Keep Your Streak Alive!"
                    content.body = "Don't break your weekly chai rating streak! Rate 3+ spots this week to keep it going."
        content.sound = .default
        
        // Schedule for 8 PM if user hasn't rated today
        var dateComponents = DateComponents()
        dateComponents.hour = 20
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: "streak_reminder",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    // MARK: - Friend Activity Notifications
    func notifyFriendActivity(friendName: String, activity: String) {
        // Check if friend activity notifications are enabled
        guard friendActivityNotifications else { return }
        
        // Check if we're in quiet hours
        guard !isInQuietHours else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "👥 \(friendName) is active!"
        content.body = activity
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1.0, repeats: false)
        let request = UNNotificationRequest(
            identifier: "friend_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    // MARK: - Friend Request Notifications
    func notifyFriendRequest(fromUserName: String) {
        // Check if friend request notifications are enabled
        guard friendRequestNotifications else { return }
        
        // Check if we're in quiet hours
        guard !isInQuietHours else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "🤝 New Friend Request"
        content.body = "\(fromUserName) wants to be your friend!"
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1.0, repeats: false)
        let request = UNNotificationRequest(
            identifier: "friendRequest_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    // MARK: - Weekly Challenge Notifications
    func notifyWeeklyChallengeAvailable(challengeName: String) {
        // Check if weekly challenge notifications are enabled
        guard weeklyChallengeNotifications else { return }
        
        // Check if we're in quiet hours
        guard !isInQuietHours else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "🎯 New Weekly Challenge"
        content.body = "\(challengeName) is now available! Tap to participate."
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1.0, repeats: false)
        let request = UNNotificationRequest(
            identifier: "weeklyChallenge_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    // MARK: - Utility Methods
    func clearAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }
    
    func getNotificationSettings() async -> UNNotificationSettings {
        return await UNUserNotificationCenter.current().notificationSettings()
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension NotificationService: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        // Handle notification tap
        let userInfo = response.notification.request.content.userInfo
        
        if let type = userInfo["type"] as? String {
            handleGamificationNotification(type: type, userInfo: userInfo)
        }
        
        completionHandler()
    }
    
    private func handleGamificationNotification(type: String, userInfo: [AnyHashable: Any]) {
        // Handle different gamification notification types
        switch type {
        case "badge_unlock":
            // Navigate to badge collection
            break
        case "achievement_unlock":
            // Navigate to achievements
            break
        case "streak_reminder":
            // Navigate to rating submission
            break
        default:
            break
        }
    }
}

// MARK: - MessagingDelegate
extension NotificationService: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        self.fcmToken = fcmToken
        
        if let token = fcmToken {
            print("✅ FCM registration token: \(token)")
            // Store token in Firestore for server-side notifications
            storeFCMToken(token)
        }
    }
    
    private func storeFCMToken(_ token: String) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let db = Firestore.firestore()
        db.collection("users").document(userId).updateData([
            "fcmToken": token,
            "lastTokenUpdate": Timestamp()
        ]) { error in
            if let error = error {
                print("❌ Error storing FCM token: \(error.localizedDescription)")
            } else {
                print("✅ FCM token stored successfully")
            }
        }
    }
}

// MARK: - Notification Preference Types
enum NotificationPreferenceType: String, CaseIterable {
    case badges = "badges"
    case achievements = "achievements"
    case streaks = "streaks"
    case weeklyChallenges = "weeklyChallenges"
    case friendActivity = "friendActivity"
    case friendRequests = "friendRequests"
    
    var displayName: String {
        switch self {
        case .badges:
            return "🎖️ Badge Unlocks"
        case .achievements:
            return "🏆 Achievement Unlocks"
        case .streaks:
            return "🔥 Streak Milestones"
        case .weeklyChallenges:
            return "🎯 Weekly Challenges"
        case .friendActivity:
            return "👥 Friend Activity"
        case .friendRequests:
            return "🤝 Friend Requests"
        }
    }
    
    var description: String {
        switch self {
        case .badges:
            return "Get notified when you earn new badges"
        case .achievements:
            return "Celebrate when you unlock achievements"
        case .streaks:
            return "Stay motivated with streak reminders"
        case .weeklyChallenges:
            return "Get notified about new challenges"
        case .friendActivity:
            return "See when friends rate new spots"
        case .friendRequests:
            return "Get notified about new friend requests"
        }
    }
}

// MARK: - Gamification Notification Types
enum GamificationNotificationType: String, CaseIterable {
    case badgeUnlock = "badge_unlock"
    case achievementUnlock = "achievement_unlock"
    case streakMilestone = "streak_milestone"
    case friendActivity = "friend_activity"
    case weeklyChallenge = "weekly_challenge"
    
    var title: String {
        switch self {
        case .badgeUnlock:
            return "🎖️ New Badge Unlocked!"
        case .achievementUnlock:
            return "🏆 Achievement Unlocked!"
        case .streakMilestone:
            return "🔥 Streak Milestone!"
        case .friendActivity:
            return "👥 Friend Activity"
        case .weeklyChallenge:
            return "🎯 Weekly Challenge"
        }
    }
    
    var body: String {
        switch self {
        case .badgeUnlock:
            return "You've earned a new badge for your chai adventures!"
        case .achievementUnlock:
            return "Congratulations on unlocking a new achievement!"
        case .streakMilestone:
            return "You've reached a new streak milestone!"
        case .friendActivity:
            return "Your friends have been active in the chai community!"
        case .weeklyChallenge:
            return "A new weekly challenge is available!"
        }
    }
    
    var identifier: String {
        return "gamification_\(rawValue)"
    }
}
