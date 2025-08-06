import SwiftUI
import FirebaseAuth
import FirebaseFirestore

class SessionStore: ObservableObject {
    @Published var user: UserProfile?
    @Published var isAuthenticated = false
    @Published var isLoading = false

    init() {
        if let currentUser = Auth.auth().currentUser,
           let _ = currentUser.email, !currentUser.uid.isEmpty {
            loadUser(from: currentUser)
        } else if let savedUserData = UserDefaults.standard.data(forKey: "currentUser"),
                  let savedUser = try? JSONDecoder().decode(UserProfile.self, from: savedUserData) {
            self.user = savedUser
            self.isAuthenticated = true
        }
    }

    func signIn(email: String, password: String, completion: @escaping (Bool, String?) -> Void) {
        isLoading = true
        Auth.auth().signIn(withEmail: email, password: password) { authResult, error in
            DispatchQueue.main.async {
                self.isLoading = false
                if let error = error as NSError? {
                    let message = self.mapAuthError(error)
                    completion(false, message)
                } else if let user = authResult?.user {
                    self.loadUser(from: user)
                    completion(true, nil)
                } else {
                    completion(false, "Unknown sign-in error")
                }
            }
        }
    }

    func signUp(email: String, password: String, displayName: String, completion: @escaping (Bool, String?) -> Void) {
        isLoading = true
        Auth.auth().createUser(withEmail: email, password: password) { authResult, error in
            DispatchQueue.main.async {
                self.isLoading = false
                if let error = error as NSError? {
                    let message = self.mapAuthError(error)
                    completion(false, message)
                } else if let user = authResult?.user {
                    let changeRequest = user.createProfileChangeRequest()
                    changeRequest.displayName = displayName
                    changeRequest.commitChanges { _ in
                        self.loadUser(from: user, fallbackName: displayName)
                        completion(true, nil)
                    }
                } else {
                    completion(false, "Unknown sign-up error")
                }
            }
        }
    }

    func signOut() {
        do {
            try Auth.auth().signOut()
            self.user = nil
            self.isAuthenticated = false
            UserDefaults.standard.removeObject(forKey: "currentUser")
        } catch {
            print("❌ Sign-out failed: \(error.localizedDescription)")
        }
    }

    func updateUserProfile(_ updatedUser: UserProfile) {
        self.user = updatedUser
        if let userData = try? JSONEncoder().encode(updatedUser) {
            UserDefaults.standard.set(userData, forKey: "currentUser")
        }
    }

    private func loadUser(from firebaseUser: FirebaseAuth.User, fallbackName: String? = nil) {
        let loadedUser = UserProfile(
            uid: firebaseUser.uid,
            displayName: firebaseUser.displayName ?? fallbackName ?? firebaseUser.email ?? "User",
            email: firebaseUser.email ?? "",
            photoURL: firebaseUser.photoURL?.absoluteString,
            friends: [],
            incomingRequests: [],
            outgoingRequests: [],
            bio: ""
        )
        self.user = loadedUser
        self.isAuthenticated = true

        if let userData = try? JSONEncoder().encode(loadedUser) {
            UserDefaults.standard.set(userData, forKey: "currentUser")
        }
    }

    private func mapAuthError(_ error: NSError) -> String {
        guard let code = AuthErrorCode(rawValue: error.code) else {
            return error.localizedDescription
        }

        switch code {
        case .invalidEmail:
            return "Invalid email format"
        case .wrongPassword:
            return "Incorrect password"
        case .emailAlreadyInUse:
            return "This email is already in use"
        case .userNotFound:
            return "No account found for this email"
        case .weakPassword:
            return "Password is too weak (min. 6 characters)"
        case .missingEmail:
            return "Please enter your email"
        case .internalError:
            return "Something went wrong. Try again."
        default:
            return error.localizedDescription
        }
    }
}
