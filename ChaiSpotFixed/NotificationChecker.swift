import Foundation
import FirebaseAuth
import FirebaseFirestore

class NotificationChecker: ObservableObject {
    @Published var showAlert = false
    @Published var alertMessage = ""

    private let db = Firestore.firestore()

    func checkForNewActivity() {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        // Fix: Query the friends subcollection instead of looking for a 'friends' field
        db.collection("users").document(uid).collection("friends").getDocuments { snapshot, error in
            if let error = error {
                print("❌ Error fetching friends for notifications: \(error.localizedDescription)")
                return
            }

            let currentFriends = snapshot?.documents.map { $0.documentID } ?? []
            let previousFriends = UserDefaults.standard.stringArray(forKey: "lastKnownFriends") ?? []

            print("👥 Current friends: \(currentFriends.count), Previous friends: \(previousFriends.count)")

            if currentFriends.count > previousFriends.count {
                DispatchQueue.main.async {
                    self.alertMessage = "You have new friends!"
                    self.showAlert = true
                }
            }

            // Save the latest friend list for future comparison
            UserDefaults.standard.set(currentFriends, forKey: "lastKnownFriends")
        }
    }
}
