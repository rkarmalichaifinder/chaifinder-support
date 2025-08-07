import SwiftUI
import FirebaseAuth
import AuthenticationServices
import CryptoKit
import FirebaseFirestore
import GoogleSignIn

class SessionStore: NSObject, ObservableObject {
    @Published var currentUser: User?
    @Published var userProfile: UserProfile?  // ✅ Add this
    private var authStateListener: AuthStateDidChangeListenerHandle?
    fileprivate var currentNonce: String?

    override init() {
        super.init()
        listen()
    }

    func listen() {
        authStateListener = Auth.auth().addStateDidChangeListener { auth, user in
            DispatchQueue.main.async {
                self.currentUser = user
                if let user = user {
                    self.loadUserProfile(uid: user.uid)
                } else {
                    self.userProfile = nil
                }
            }
        }
    }

    func loadUserProfile(uid: String) {
        let db = Firestore.firestore()
        db.collection("users").document(uid).getDocument { snapshot, error in
            if let error = error {
                print("❌ Failed to load user profile: \(error.localizedDescription)")
                return
            }
            if let data = try? snapshot?.data(as: UserProfile.self) {
                DispatchQueue.main.async {
                    self.userProfile = data
                    print("✅ User profile loaded")
                }
            }
        }
    }

    func signOut() {
        do {
            try Auth.auth().signOut()
            self.currentUser = nil
            self.userProfile = nil
            print("✅ Signed out")
        } catch {
            print("❌ Error signing out: \(error.localizedDescription)")
        }
    }

    // MARK: - Apple Sign-In (local only, not Firebase)

    func signInWithApple() {
        let nonce = randomNonceString()
        currentNonce = nonce

        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    // MARK: - Google Sign-In

    func signInWithGoogle() {
        guard let presentingVC = UIApplication.shared.connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.keyWindow?.rootViewController }).first else {
            print("❌ No root view controller found.")
            return
        }

        GIDSignIn.sharedInstance.signIn(withPresenting: presentingVC) { result, error in
            if let error = error {
                print("❌ Google Sign-In failed: \(error.localizedDescription)")
                return
            }

            guard let user = result?.user,
                  let idToken = user.idToken?.tokenString else {
                print("❌ Missing Google ID Token")
                return
            }

            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: user.accessToken.tokenString
            )

            Auth.auth().signIn(with: credential) { authResult, error in
                if let error = error {
                    print("❌ Firebase sign-in failed: \(error.localizedDescription)")
                    return
                }
                DispatchQueue.main.async {
                    self.currentUser = authResult?.user
                }
            }
        }
    }

    // MARK: - Email/Password Sign-In

    func signInWithEmail(email: String, password: String) async {
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            DispatchQueue.main.async {
                self.currentUser = result.user
                self.loadUserProfile(uid: result.user.uid)
            }
            print("✅ Signed in with email: \(result.user.uid)")
        } catch {
            print("❌ Email sign-in error: \(error.localizedDescription)")
        }
    }

    func signUpWithEmail(email: String, password: String) async {
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            let newUser = UserProfile(
                uid: result.user.uid,
                displayName: email.components(separatedBy: "@").first ?? "User",
                email: email,
                photoURL: nil,
                friends: [],
                incomingRequests: [],
                outgoingRequests: [],
                bio: nil
            )
            try Firestore.firestore().collection("users").document(newUser.uid).setData(from: newUser)
            DispatchQueue.main.async {
                self.currentUser = result.user
                self.userProfile = newUser
            }
            print("✅ Signed up with email: \(result.user.uid)")
        } catch {
            print("❌ Email sign-up error: \(error.localizedDescription)")
        }
    }

    func updateBio(to newBio: String) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        let db = Firestore.firestore()
        let ref = db.collection("users").document(uid)

        do {
            try await ref.setData(["bio": newBio], merge: true)
            DispatchQueue.main.async {
                self.userProfile?.bio = newBio
            }
            print("✅ Bio updated")
        } catch {
            print("❌ Failed to update bio: \(error.localizedDescription)")
        }
    }

    // MARK: - Helpers

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.map { String(format: "%02x", $0) }.joined()
    }

    private func randomNonceString(length: Int = 32) -> String {
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            var random: UInt8 = 0
            let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
            if errorCode == errSecSuccess && random < charset.count {
                result.append(charset[Int(random)])
                remainingLength -= 1
            }
        }

        return result
    }
}

extension SessionStore: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        print("⚠️ Apple Sign-In received, but not hooked up to Firebase in this build.")
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        print("❌ Apple Sign-In failed: \(error.localizedDescription)")
    }
}

extension SessionStore: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first ?? ASPresentationAnchor()
    }
}
