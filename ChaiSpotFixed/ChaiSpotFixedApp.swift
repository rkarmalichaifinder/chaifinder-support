import SwiftUI

@main
struct ChaiSpotFixedApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var sessionStore = SessionStore()
    @StateObject private var weeklyRankingService = WeeklyRankingService.shared

    var body: some Scene {
        WindowGroup {
            RootRouter()
                .environmentObject(sessionStore)
                .environmentObject(weeklyRankingService)
                .onAppear {
                    sessionStore.initializeIfNeeded()
                    sessionStore.setupAuthListener()   // This will handle current user state automatically
                    
                    // Schedule weekly ranking notification
                    weeklyRankingService.scheduleWeeklyRankingNotification()
                    
                    // Check if it's time to send weekly ranking notification
                    weeklyRankingService.checkAndSendWeeklyRanking()
                    
                    print("🟢 App bootstrapped")
                }
        }
    }
}
