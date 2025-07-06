import Foundation
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
                print("❌ Error fetching user for notifications: \(error.localizedDescription)")
                return
            }

            guard let data = snapshot?.data() else {
                print("⚠️ No data found for user")
                return
            }

            let currentFriends = data["friends"] as? [String] ?? []
            let previousFriends = UserDefaults.standard.stringArray(forKey: "lastKnownFriends") ?? []

            print("👥 Current friends: \(currentFriends.count), Previous friends: \(previousFriends.count)")

            if currentFriends.count > previousFriends.count {
                self.alertMessage = "You have new friends!"
                self.showAlert = true
            }

            // Save the latest friend list for future comparison
            UserDefaults.standard.set(currentFriends, forKey: "lastKnownFriends")
        }
    }
}
