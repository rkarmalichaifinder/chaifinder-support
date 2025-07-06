import Foundation
import FirebaseAuth
import Combine

class SessionStore: ObservableObject {
    @Published var user: User? = nil
    var handle: AuthStateDidChangeListenerHandle?

    var isLoggedIn: Bool {
        return user != nil
    }

    init() {
        listen()
    }

    func listen() {
        handle = Auth.auth().addStateDidChangeListener { auth, user in
            self.user = user
        }
    }

    func signOut() {
        do {
            try Auth.auth().signOut()
            self.user = nil
        } catch {
            print("Error signing out: \(error.localizedDescription)")
        }
    }

    deinit {
        if let handle = handle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
}

