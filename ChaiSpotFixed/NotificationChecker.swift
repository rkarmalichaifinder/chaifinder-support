import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore
import FirebaseCore

class NotificationChecker: ObservableObject {
    @Published var showAlert = false
    @Published var alertMessage = ""

    private lazy var db: Firestore = {
        // Only create Firestore instance when actually needed
        // Firebase should be configured by SessionStore before this is called
        return Firestore.firestore()
    }()

    func checkForNewActivity() {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        db.collection("users").document(uid).getDocument { snapshot, error in
            if let error = error {
                return
            }

            guard let data = snapshot?.data() else {
                return
            }

            let currentFriends = data["friends"] as? [String] ?? []
            let previousFriends = UserDefaults.standard.stringArray(forKey: "lastKnownFriends") ?? []

            if currentFriends.count > previousFriends.count {
                self.alertMessage = "You have new friends!"
                self.showAlert = true
            }

            // Save the latest friend list for future comparison
            UserDefaults.standard.set(currentFriends, forKey: "lastKnownFriends")
        }
    }
}
