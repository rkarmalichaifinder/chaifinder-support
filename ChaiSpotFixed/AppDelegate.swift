import UIKit
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        // Configure Firebase with custom options
        let options = FirebaseOptions(
            googleAppID: "1:1031321306480:ios:a038d74da45f2aa344bbb5",
            gcmSenderID: "587784566464"
        )
        options.bundleID = "rfk.ChaiSpotFixed"
        options.apiKey = "AIzaSyCy_E7F5obF3AyVy_JQGFg7u-U44G4IeUg"
        options.clientID = "587784566464-a20p386bmiuvgaigq61snprnbb0fqios.apps.googleusercontent.com"
        options.projectID = "chaispot-e4e9b"

        FirebaseApp.configure(options: options)

        print("✅ Firebase configured in AppDelegate")
        print("✅ Firebase clientID: \(FirebaseApp.app()?.options.clientID ?? "nil")")
        print("✅ Firebase GOOGLE_APP_ID: \(FirebaseApp.app()?.options.googleAppID ?? "nil")")
        
        return true
    }
}
