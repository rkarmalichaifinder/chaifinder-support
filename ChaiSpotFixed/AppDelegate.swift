import UIKit
import FirebaseCore
import FirebaseMessaging

class AppDelegate: NSObject, UIApplicationDelegate {
    
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Configure Firebase at app launch to prevent hang detection
        print("🔄 Configuring Firebase at app launch...")
        FirebaseApp.configure()
        print("✅ Firebase configured successfully at app launch")
        
        // Initialize notification service
        _ = NotificationService.shared
        
        return true
    }
    
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let sceneConfig = UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
        sceneConfig.delegateClass = SceneDelegate.self
        return sceneConfig
    }

    func application(_ application: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        // Handle deep links and custom URL schemes
        return true
    }
    
    // MARK: - Push Notification Handling
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        NotificationService.shared.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        NotificationService.shared.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        // Handle incoming push notifications
        print("📱 Received remote notification: \(userInfo)")
        
        // Process gamification notifications
        if let type = userInfo["type"] as? String {
            handleGamificationPushNotification(type: type, userInfo: userInfo)
        }
        
        completionHandler(.newData)
    }
    
    private func handleGamificationPushNotification(type: String, userInfo: [AnyHashable: Any]) {
        switch type {
        case "badge_unlock":
            // Handle badge unlock notification
            if let badgeId = userInfo["badge_id"] as? String {
                print("🎖️ Badge unlock notification: \(badgeId)")
            }
        case "achievement_unlock":
            // Handle achievement unlock notification
            if let achievementId = userInfo["achievement_id"] as? String {
                print("🏆 Achievement unlock notification: \(achievementId)")
            }
        case "streak_reminder":
            // Handle streak reminder notification
            print("🔥 Streak reminder notification")
        case "friend_activity":
            // Handle friend activity notification
            if let friendName = userInfo["friend_name"] as? String {
                print("👥 Friend activity notification: \(friendName)")
            }
        case "weekly_challenge":
            // Handle weekly challenge notification
            print("🎯 Weekly challenge notification")
        default:
            print("📱 Unknown notification type: \(type)")
        }
    }
}

// MARK: - SceneDelegate

class SceneDelegate: NSObject, UIWindowSceneDelegate {
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {}
    func sceneDidDisconnect(_ scene: UIScene) {}
    func sceneDidBecomeActive(_ scene: UIScene) {
        // Clear app icon badge when app becomes active
        UIApplication.shared.applicationIconBadgeNumber = 0
        print("🧹 App icon badge cleared")
    }
    func sceneWillResignActive(_ scene: UIScene) {}
    func sceneWillEnterForeground(_ scene: UIScene) {}
    func sceneDidEnterBackground(_ scene: UIScene) {}
}
