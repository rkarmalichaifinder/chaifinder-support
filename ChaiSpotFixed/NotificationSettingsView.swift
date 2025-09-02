import SwiftUI

struct NotificationSettingsView: View {
    @StateObject private var notificationManager = SmartNotificationManager.shared
    @State private var preferences: NotificationPreferences
    @State private var showingResetAlert = false
    
    init() {
        _preferences = State(initialValue: SmartNotificationManager.shared.preferences)
    }
    
    var body: some View {
        NavigationView {
            Form {
                // Notification Types Section
                Section(header: Text("Notification Types")) {
                    ForEach(FeedItemType.allCases, id: \.self) { type in
                        Toggle(isOn: Binding(
                            get: { preferences.enabledTypes.contains(type) },
                            set: { isEnabled in
                                if isEnabled {
                                    preferences.enabledTypes.insert(type)
                                } else {
                                    preferences.enabledTypes.remove(type)
                                }
                                updatePreferences()
                            }
                        )) {
                            HStack {
                                Image(systemName: type.icon)
                                    .foregroundColor(iconColor(for: type))
                                    .frame(width: 20)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(type.displayName)
                                        .font(DesignSystem.Typography.bodyMedium)
                                        .foregroundColor(DesignSystem.Colors.textPrimary)
                                    
                                    Text(description(for: type))
                                        .font(DesignSystem.Typography.caption)
                                        .foregroundColor(DesignSystem.Colors.textSecondary)
                                }
                            }
                        }
                    }
                }
                
                // Limits Section
                Section(header: Text("Notification Limits")) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Max per hour")
                            Spacer()
                            Text("\(preferences.maxNotificationsPerHour)")
                                .foregroundColor(DesignSystem.Colors.primary)
                        }
                        
                        Slider(
                            value: Binding(
                                get: { Double(preferences.maxNotificationsPerHour) },
                                set: { preferences.maxNotificationsPerHour = Int($0) }
                            ),
                            in: 1...10,
                            step: 1
                        )
                        .onChange(of: preferences.maxNotificationsPerHour) { _ in
                            updatePreferences()
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Max per day")
                            Spacer()
                            Text("\(preferences.maxNotificationsPerDay)")
                                .foregroundColor(DesignSystem.Colors.primary)
                        }
                        
                        Slider(
                            value: Binding(
                                get: { Double(preferences.maxNotificationsPerDay) },
                                set: { preferences.maxNotificationsPerDay = Int($0) }
                            ),
                            in: 5...50,
                            step: 5
                        )
                        .onChange(of: preferences.maxNotificationsPerDay) { _ in
                            updatePreferences()
                        }
                    }
                }
                
                // Quiet Hours Section
                Section(header: Text("Quiet Hours")) {
                    HStack {
                        Text("Start time")
                        Spacer()
                        Picker("Start", selection: Binding(
                            get: { preferences.quietHoursStart },
                            set: { preferences.quietHoursStart = $0 }
                        )) {
                            ForEach(0..<24, id: \.self) { hour in
                                Text(timeString(hour)).tag(hour)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .onChange(of: preferences.quietHoursStart) { _ in
                            updatePreferences()
                        }
                    }
                    
                    HStack {
                        Text("End time")
                        Spacer()
                        Picker("End", selection: Binding(
                            get: { preferences.quietHoursEnd },
                            set: { preferences.quietHoursEnd = $0 }
                        )) {
                            ForEach(0..<24, id: \.self) { hour in
                                Text(timeString(hour)).tag(hour)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .onChange(of: preferences.quietHoursEnd) { _ in
                            updatePreferences()
                        }
                    }
                    
                    if isInQuietHours() {
                        HStack {
                            Image(systemName: "moon.fill")
                                .foregroundColor(.blue)
                            Text("Currently in quiet hours")
                                .foregroundColor(.blue)
                                .font(DesignSystem.Typography.caption)
                        }
                    }
                }
                
                // Sound & Vibration Section
                Section(header: Text("Sound & Vibration")) {
                    Toggle("Sound", isOn: Binding(
                        get: { preferences.enableSound },
                        set: { preferences.enableSound = $0 }
                    ))
                    .onChange(of: preferences.enableSound) { _ in
                        updatePreferences()
                    }
                    
                    Toggle("Vibration", isOn: Binding(
                        get: { preferences.enableVibration },
                        set: { preferences.enableVibration = $0 }
                    ))
                    .onChange(of: preferences.enableVibration) { _ in
                        updatePreferences()
                    }
                    
                    Toggle("Badge Count", isOn: Binding(
                        get: { preferences.enableBadge },
                        set: { preferences.enableBadge = $0 }
                    ))
                    .onChange(of: preferences.enableBadge) { _ in
                        updatePreferences()
                    }
                }
                
                // Statistics Section
                Section(header: Text("Statistics")) {
                    HStack {
                        Text("Notifications today")
                        Spacer()
                        Text("\(notificationManager.notificationCount)")
                            .foregroundColor(DesignSystem.Colors.primary)
                    }
                    
                    if let lastTime = notificationManager.lastNotificationTime {
                        HStack {
                            Text("Last notification")
                            Spacer()
                            Text(lastTime, style: .relative)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                                .font(DesignSystem.Typography.caption)
                        }
                    }
                }
                
                // Reset Section
                Section {
                    Button("Reset Notification Count") {
                        showingResetAlert = true
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.large)
            .alert("Reset Notification Count", isPresented: $showingResetAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    notificationManager.resetNotificationCount()
                }
            } message: {
                Text("This will reset your daily notification count to 0.")
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func updatePreferences() {
        notificationManager.updatePreferences(preferences)
    }
    
    private func iconColor(for type: FeedItemType) -> Color {
        switch type {
        case .review: return DesignSystem.Colors.primary
        case .newUser: return DesignSystem.Colors.info
        case .newSpot: return DesignSystem.Colors.secondary
        case .achievement: return .orange
        case .friendActivity: return DesignSystem.Colors.success
        case .weeklyChallenge: return .red
        case .weeklyRanking: return .purple
        }
    }
    
    private func description(for type: FeedItemType) -> String {
        switch type {
        case .review: return "New reviews from friends and community"
        case .newUser: return "When new users join chai finder"
        case .newSpot: return "When new chai spots are discovered"
        case .achievement: return "When users earn achievements"
        case .friendActivity: return "Friend activities and updates"
        case .weeklyChallenge: return "Weekly challenge updates"
        case .weeklyRanking: return "Weekly ranking updates"
        }
    }
    
    private func timeString(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        
        let calendar = Calendar.current
        let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
        
        return formatter.string(from: date)
    }
    
    private func isInQuietHours() -> Bool {
        let calendar = Calendar.current
        let now = Date()
        let hour = calendar.component(.hour, from: now)
        
        if preferences.quietHoursStart < preferences.quietHoursEnd {
            return hour >= preferences.quietHoursStart || hour < preferences.quietHoursEnd
        } else {
            return hour >= preferences.quietHoursStart && hour < preferences.quietHoursEnd
        }
    }
}

struct NotificationSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NotificationSettingsView()
    }
}
