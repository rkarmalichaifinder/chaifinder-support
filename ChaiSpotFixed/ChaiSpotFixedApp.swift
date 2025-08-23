import SwiftUI

@main
struct ChaiSpotFixedApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var sessionStore = SessionStore()

    var body: some Scene {
        WindowGroup {
            RootRouter()
                .environmentObject(sessionStore)
                .onAppear {
                    sessionStore.initializeIfNeeded()
                    sessionStore.setupAuthListener()   // This will handle current user state automatically
                    print("🟢 App bootstrapped")
                }
        }
    }
}
