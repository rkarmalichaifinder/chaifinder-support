import SwiftUI
import FirebaseCore
import FirebaseAuth

@main
struct ChaiSpotFixedApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate  // Required for Firebase

    @State private var showSplash = true

    init() {
        // Firebase configuration is now handled in AppDelegate
        // This ensures proper timing and protocol conformance
        _ = AuthObserver.shared  // Optional: your own observer setup
    }

    var body: some Scene {
        WindowGroup {
            if showSplash {
                SplashScreenView()
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            showSplash = false
                        }
                    }
            } else {
                MainAppView()  // Your main map or home screen
            }
        }
    }
}
