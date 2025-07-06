import Foundation
import FirebaseAuth

extension Notification.Name {
    static let authStateChanged = Notification.Name("authStateChanged")
}

class AuthObserver {
    static let shared = AuthObserver()

    private init() {
        Auth.auth().addStateDidChangeListener { _, _ in
            NotificationCenter.default.post(name: .authStateChanged, object: nil)
        }
    }
}
