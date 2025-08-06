import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore

class NotificationChecker: ObservableObject {
    @Published var showAlert = false
    @Published var alertMessage = ""

    private let db = Firestore.firestore()

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
