import SwiftUI
import FirebaseCore
import FirebaseAuth

@main
struct ChaiSpotFixedApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate  // Required for Firebase

    @State private var showSplash = true

    init() {
        let options = FirebaseOptions(
            googleAppID: "1:1031321306480:ios:a038d74da45f2aa344bbb5",
            gcmSenderID: "587784566464"
        )
        options.bundleID = "rfk.ChaiSpotFixed"
        options.apiKey = "AIzaSyCy_E7F5obF3AyVy_JQGFg7u-U44G4IeUg"
        options.clientID = "587784566464-a20p386bmiuvgaigq61snprnbb0fqios.apps.googleusercontent.com"
        options.projectID = "chaispot-e4e9b"

        FirebaseApp.configure(options: options)

        print("✅ Firebase clientID: \(FirebaseApp.app()?.options.clientID ?? "nil")")
        print("✅ Firebase GOOGLE_APP_ID: \(FirebaseApp.app()?.options.googleAppID ?? "nil")")
        print("✅ Firebase Bundle ID: \(FirebaseApp.app()?.options.bundleID ?? "nil")")
        print("✅ App Bundle ID: \(Bundle.main.bundleIdentifier ?? "nil")")

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
