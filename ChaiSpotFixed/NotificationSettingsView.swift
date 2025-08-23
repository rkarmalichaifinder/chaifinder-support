import SwiftUI
import UserNotifications

struct NotificationSettingsView: View {
    @StateObject private var notificationService = NotificationService.shared
    @State private var showingPermissionAlert = false
    @State private var permissionAlertMessage = ""
    
    var body: some View {
        NavigationView {
            List {
                // Notification Status Section
                Section(header: Text("Notification Status")) {
                    HStack {
                        Image(systemName: notificationService.isNotificationsEnabled ? "bell.fill" : "bell.slash.fill")
                            .foregroundColor(notificationService.isNotificationsEnabled ? .green : .red)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(notificationService.isNotificationsEnabled ? "Notifications Enabled" : "Notifications Disabled")
                                .font(.headline)
                            Text(notificationService.isNotificationsEnabled ? "You'll receive all chai-related notifications" : "Enable notifications to stay updated")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if !notificationService.isNotificationsEnabled {
                            Button("Enable") {
                                requestNotificationPermissions()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .padding(.vertical, 8)
                    
                    // Notification Summary
                    if notificationService.isNotificationsEnabled {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Active Notifications")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text("\(notificationService.enabledNotificationCount) of 6 notification types enabled")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if notificationService.quietHoursEnabled {
                                Image(systemName: "moon.fill")
                                    .foregroundColor(.blue)
                                    .font(.title2)
                            }
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                        
                        // Additional status info
                        if notificationService.digestNotifications || notificationService.quietHoursEnabled {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Notification Settings")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    
                                    HStack(spacing: 12) {
                                        if notificationService.digestNotifications {
                                            Label("Digest Mode", systemImage: "clock")
                                                .font(.caption)
                                                .foregroundColor(.green)
                                        }
                                        
                                        if notificationService.quietHoursEnabled {
                                            Label("Quiet Hours", systemImage: "moon")
                                                .font(.caption)
                                                .foregroundColor(.blue)
                                        }
                                    }
                                }
                                
                                Spacer()
                                
                                if notificationService.pendingNotificationCount > 0 {
                                    Text("\(notificationService.pendingNotificationCount) pending")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.orange.opacity(0.2))
                                        .cornerRadius(4)
                                }
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                }
                
                // Gamification Notifications Section
                Section(header: Text("Gamification Notifications")) {
                    NotificationToggleRow(
                        title: NotificationPreferenceType.badges.displayName,
                        description: NotificationPreferenceType.badges.description,
                        isEnabled: notificationService.badgeNotifications,
                        onToggle: { enabled in
                            notificationService.updateNotificationPreference(type: .badges, enabled: enabled)
                        }
                    )
                    
                    NotificationToggleRow(
                        title: NotificationPreferenceType.achievements.displayName,
                        description: NotificationPreferenceType.achievements.description,
                        isEnabled: notificationService.achievementNotifications,
                        onToggle: { enabled in
                            notificationService.updateNotificationPreference(type: .achievements, enabled: enabled)
                        }
                    )
                    
                    NotificationToggleRow(
                        title: NotificationPreferenceType.streaks.displayName,
                        description: NotificationPreferenceType.streaks.description,
                        isEnabled: notificationService.streakNotifications,
                        onToggle: { enabled in
                            notificationService.updateNotificationPreference(type: .streaks, enabled: enabled)
                        }
                    )
                    
                    NotificationToggleRow(
                        title: NotificationPreferenceType.weeklyChallenges.displayName,
                        description: NotificationPreferenceType.weeklyChallenges.description,
                        isEnabled: notificationService.weeklyChallengeNotifications,
                        onToggle: { enabled in
                            notificationService.updateNotificationPreference(type: .weeklyChallenges, enabled: enabled)
                        }
                    )
                }
                
                // Social Notifications Section
                Section(header: Text("Social Notifications")) {
                    NotificationToggleRow(
                        title: NotificationPreferenceType.friendActivity.displayName,
                        description: NotificationPreferenceType.friendActivity.description,
                        isEnabled: notificationService.friendActivityNotifications,
                        onToggle: { enabled in
                            notificationService.updateNotificationPreference(type: .friendActivity, enabled: enabled)
                        }
                    )
                    
                    NotificationToggleRow(
                        title: NotificationPreferenceType.friendRequests.displayName,
                        description: NotificationPreferenceType.friendRequests.description,
                        isEnabled: notificationService.friendRequestNotifications,
                        onToggle: { enabled in
                            notificationService.updateNotificationPreference(type: .friendRequests, enabled: enabled)
                        }
                    )
                }
                
                // Notification Timing Section
                Section(header: Text("Notification Timing")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Streak Reminders")
                            .font(.headline)
                        Text("Daily reminders at 8:00 PM to maintain your streak")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Text("Time")
                            Spacer()
                            Text("8:00 PM")
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 4)
                    }
                    .padding(.vertical, 8)
                    
                    // Quiet Hours Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Quiet Hours")
                                .font(.headline)
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { notificationService.quietHoursEnabled },
                                set: { enabled in
                                    notificationService.updateQuietHours(
                                        enabled: enabled,
                                        start: notificationService.quietHoursStart,
                                        end: notificationService.quietHoursEnd
                                    )
                                }
                            ))
                            .labelsHidden()
                        }
                        
                        if notificationService.quietHoursEnabled {
                            Text("Notifications will be silenced during quiet hours")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("Start Time")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    DatePicker("", selection: Binding(
                                        get: { notificationService.quietHoursStart },
                                        set: { start in
                                            notificationService.updateQuietHours(
                                                enabled: notificationService.quietHoursEnabled,
                                                start: start,
                                                end: notificationService.quietHoursEnd
                                            )
                                        }
                                    ), displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing) {
                                    Text("End Time")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    DatePicker("", selection: Binding(
                                        get: { notificationService.quietHoursEnd },
                                        set: { end in
                                            notificationService.updateQuietHours(
                                                enabled: notificationService.quietHoursEnabled,
                                                start: notificationService.quietHoursStart,
                                                end: end
                                            )
                                        }
                                    ), displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                                }
                            }
                        }
                    }
                    .padding(.vertical, 8)
                    
                    // Digest Notifications Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Daily Digest")
                                .font(.headline)
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { notificationService.digestNotifications },
                                set: { enabled in
                                    notificationService.updateDigestSettings(
                                        enabled: enabled,
                                        time: notificationService.digestTime
                                    )
                                }
                            ))
                            .labelsHidden()
                        }
                        
                        if notificationService.digestNotifications {
                            Text("Receive a daily summary of all notifications at your preferred time")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            HStack {
                                Text("Digest Time")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                DatePicker("", selection: Binding(
                                    get: { notificationService.digestTime },
                                    set: { time in
                                        notificationService.updateDigestSettings(
                                            enabled: notificationService.digestNotifications,
                                            time: time
                                        )
                                    }
                                ), displayedComponents: .hourAndMinute)
                                .labelsHidden()
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                // FCM Token Section (for debugging)
                if let fcmToken = notificationService.fcmToken {
                    Section(header: Text("Technical Info")) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("FCM Token")
                                .font(.headline)
                            Text(fcmToken)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(3)
                            
                            Button("Copy Token") {
                                UIPasteboard.general.string = fcmToken
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                // Actions Section
                Section {
                    Button("Test All Notifications") {
                        testAllNotifications()
                    }
                    .foregroundColor(.blue)
                    
                    Button("Test Badge Notification") {
                        testBadgeNotification()
                    }
                    .foregroundColor(.green)
                    
                    Button("Test Friend Request") {
                        testFriendRequestNotification()
                    }
                    .foregroundColor(.purple)
                    
                    Button("Test Digest Notification") {
                        testDigestNotification()
                    }
                    .foregroundColor(.indigo)
                    
                    Button("Clear All Notifications") {
                        notificationService.clearAllNotifications()
                    }
                    .foregroundColor(.orange)
                    
                    Button("Reset Notification Settings") {
                        resetNotificationSettings()
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.large)
            .alert("Notification Permission", isPresented: $showingPermissionAlert) {
                Button("OK") { }
            } message: {
                Text(permissionAlertMessage)
            }
        }
    }
    
    // MARK: - Actions
    
    private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                if granted {
                    notificationService.isNotificationsEnabled = true
                    notificationService.registerForRemoteNotifications()
                    permissionAlertMessage = "Notifications enabled! You'll now receive chai-related updates."
                } else {
                    permissionAlertMessage = "Notifications are disabled. You can enable them in Settings > Notifications > Chai Finder."
                }
                showingPermissionAlert = true
            }
        }
    }
    
    private func testAllNotifications() {
        // Test all notification types with delays
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            notificationService.scheduleGamificationNotification(type: .badgeUnlock, delay: 0.5)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            notificationService.scheduleGamificationNotification(type: .achievementUnlock, delay: 0.5)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            notificationService.scheduleGamificationNotification(type: .streakMilestone, delay: 0.5)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            notificationService.scheduleGamificationNotification(type: .weeklyChallenge, delay: 0.5)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            notificationService.notifyFriendActivity(friendName: "Test Friend", activity: "rated a new chai spot!")
        }
    }
    
    private func testBadgeNotification() {
        notificationService.scheduleGamificationNotification(
            type: .badgeUnlock,
            delay: 2.0
        )
    }
    
    private func testFriendRequestNotification() {
        notificationService.notifyFriendRequest(fromUserName: "Test User")
    }
    
    private func testDigestNotification() {
        // Add some test notifications to the pending queue
        notificationService.updateNotificationPreference(type: .badges, enabled: true)
        notificationService.updateNotificationPreference(type: .achievements, enabled: true)
        notificationService.updateNotificationPreference(type: .friendActivity, enabled: true)
        
        // Add test notifications to pending queue
        notificationService.notifyBadgeUnlocked(badge: Badge(
            id: "test1", 
            name: "First Timer", 
            description: "Your first chai rating", 
            iconName: "1.circle.fill", 
            category: .firstSteps, 
            requirement: 1, 
            rarity: .common
        ))
        notificationService.notifyAchievementUnlocked(achievement: Achievement(id: "test1", name: "Chai Explorer", description: "Rated 5 different spots", points: 50))
        notificationService.notifyFriendActivity(friendName: "Test Friend", activity: "rated a new chai spot!")
        
        // Trigger digest notification
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            notificationService.triggerDigestNotification()
        }
    }
    
    private func resetNotificationSettings() {
        // Clear all notifications
        notificationService.clearAllNotifications()
        
        // Reset to default settings
        notificationService.resetNotificationPreferences()
        
        permissionAlertMessage = "Notification settings have been reset to defaults."
        showingPermissionAlert = true
    }
}

// MARK: - Notification Toggle Row
struct NotificationToggleRow: View {
    let title: String
    let description: String
    let isEnabled: Bool
    let onToggle: (Bool) -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: Binding(
                get: { isEnabled },
                set: { onToggle($0) }
            ))
            .labelsHidden()
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    NotificationSettingsView()
}
