import SwiftUI

extension Notification.Name {
    static let authStateChanged = Notification.Name("authStateChanged")
    static let savedSpotsChanged = Notification.Name("savedSpotsChanged")
    static let tasteSetupCompleted = Notification.Name("tasteSetupCompleted")
}

// AuthObserver removed since we're using local authentication
