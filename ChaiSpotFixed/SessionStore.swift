import SwiftUI
import UIKit
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import AuthenticationServices
import CryptoKit
import GoogleSignIn

// MARK: - SessionStore

class SessionStore: NSObject, ObservableObject,
                    ASAuthorizationControllerDelegate,
                    ASAuthorizationControllerPresentationContextProviding {

    // MARK: Published state
    @Published var currentUser: User?
    @Published var userProfile: UserProfile?
    @Published var isLoading = true

    // MARK: Private state
    private var authStateListener: AuthStateDidChangeListenerHandle?
    private var didInitialize = false
    private var didAttachListener = false
    private var currentNonce: String?

    // MARK: Lifecycle
    override init() {
        super.init()
        print("✅ SessionStore initialized")
    }

    deinit {
        if let h = authStateListener {
            Auth.auth().removeStateDidChangeListener(h)
        }
    }

    // MARK: - Bootstrap / Listener

    /// Call once from App root
    func initializeIfNeeded() {
        guard !didInitialize else {
            print("⚙️ Already initialized, skipping")
            return
        }
        didInitialize = true
        print("🔄 initializeIfNeeded (Firebase should already be configured in AppDelegate)")
        DispatchQueue.main.async { self.isLoading = true }
    }

    /// Attach the Firebase auth listener (safe to call once)
    func setupAuthListener() {
        guard !didAttachListener else {
            print("👂 Already attached listener, skipping")
            return
        }
        didAttachListener = true
        print("👂 Attaching auth listener")

        // Immediate snapshot
        let u = Auth.auth().currentUser
        DispatchQueue.main.async {
            self.currentUser = u
            if let u { self.loadUserProfile(uid: u.uid) } else { self.userProfile = nil }
        }

        // Continuous updates
        let handle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
            DispatchQueue.main.async {
                self.currentUser = user
                if let user { self.loadUserProfile(uid: user.uid) } else { self.userProfile = nil }
                self.isLoading = false
                print("👤 Auth state changed. user: \(user?.uid ?? "nil")")
            }
        }

        DispatchQueue.main.async {
            self.authStateListener = handle
            print("✅ Auth listener set up successfully")
        }
    }

    /// Optional: call after splash
    func checkCurrentUser() {
        let u = Auth.auth().currentUser
        DispatchQueue.main.async {
            self.currentUser = u
            self.isLoading = false
            print("🔎 checkCurrentUser: \(u?.uid ?? "nil")")
        }
    }

    // MARK: - Firestore Profile

    func loadUserProfile(uid: String) {
        Firestore.firestore().collection("users").document(uid).getDocument { snapshot, error in
            if let error = error {
                print("❌ Failed to load user profile: \(error.localizedDescription)")
                return
            }

            guard let doc = snapshot, doc.exists else {
                // Create minimal profile so edits persist
                let email = Auth.auth().currentUser?.email ?? "unknown"
                let display = email.split(separator: "@").first.map(String.init) ?? "User"
                let newProfile: [String: Any] = [
                    "uid": uid,
                    "displayName": display,
                    "email": email,
                    "photoURL": NSNull(),
                    "friends": [],
                    "incomingRequests": [],
                    "outgoingRequests": [],
                    "bio": NSNull()
                ]
                Firestore.firestore().collection("users").document(uid).setData(newProfile, merge: true) { err in
                    if let err { print("❌ Auto-create user profile failed: \(err.localizedDescription)") ; return }
                    print("✅ Auto-created user profile for \(uid)")
                    self.loadUserProfile(uid: uid)
                }
                return
            }

            let data = doc.data() ?? [:]
            let profile = UserProfile(
                id: doc.documentID,
                uid: data["uid"] as? String ?? uid,
                displayName: data["displayName"] as? String ?? "Unknown User",
                email: data["email"] as? String ?? "unknown",
                photoURL: data["photoURL"] as? String,
                friends: data["friends"] as? [String] ?? [],
                incomingRequests: data["incomingRequests"] as? [String] ?? [],
                outgoingRequests: data["outgoingRequests"] as? [String] ?? [],
                bio: data["bio"] as? String
            )
            DispatchQueue.main.async {
                self.userProfile = profile
                print("✅ User profile loaded with bio: \(profile.bio ?? "nil")")
            }
        }
    }

    // MARK: - Sign Out

    func signOut() {
        do {
            try Auth.auth().signOut()
            DispatchQueue.main.async {
                self.currentUser = nil
                self.userProfile = nil
            }
            print("✅ Signed out")
        } catch {
            print("❌ Sign out error: \(error.localizedDescription)")
        }
    }

    // MARK: - Apple Sign-In (Firebase 12.1, SPM)

    func signInWithApple() {
        isLoading = true

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

    // Delegate: success
    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithAuthorization authorization: ASAuthorization) {
        guard
            let cred = authorization.credential as? ASAuthorizationAppleIDCredential,
            let tokenData = cred.identityToken,
            let idToken = String(data: tokenData, encoding: .utf8),
            let nonce = currentNonce
        else {
            print("❌ Apple: Missing identity token or nonce.")
            DispatchQueue.main.async { self.isLoading = false }
            return
        }

        // Firebase 12.x API for Apple credential
        let firebaseCred = OAuthProvider.appleCredential(
            withIDToken: idToken,
            rawNonce: nonce,
            fullName: cred.fullName
        )

        Auth.auth().signIn(with: firebaseCred) { authResult, error in
            if let error = error {
                self.handleAuthError(error, pendingCredential: firebaseCred)
                DispatchQueue.main.async { self.isLoading = false }
                return
            }

            if let authResult {
                print("🍎 Apple sign-in success: \(authResult.user.uid)")

                // Persist displayName on first consent
                if let name = cred.fullName, (name.givenName != nil || name.familyName != nil) {
                    let display = [name.givenName, name.familyName].compactMap { $0 }.joined(separator: " ")
                    let change = authResult.user.createProfileChangeRequest()
                    change.displayName = display.isEmpty ? nil : display
                    change.commitChanges(completion: nil)
                }

                DispatchQueue.main.async {
                    self.currentUser = authResult.user
                    self.isLoading = false
                }
            } else {
                DispatchQueue.main.async { self.isLoading = false }
            }
        }
    }

    // Delegate: failure
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        print("❌ Apple Sign-In failed: \(error.localizedDescription)")
        DispatchQueue.main.async { self.isLoading = false }
    }

    // iPhone + iPad anchor
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first ?? ASPresentationAnchor()
    }

    // MARK: - Google Sign-In

    func signInWithGoogle() {
        guard let presentingVC = UIApplication.shared.connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.keyWindow?.rootViewController }).first else {
            print("❌ No root view controller found.")
            return
        }

        isLoading = true
        GIDSignIn.sharedInstance.signIn(withPresenting: presentingVC) { result, error in
            if let error = error {
                self.isLoading = false
                print("❌ Google Sign-In failed: \(error.localizedDescription)")
                return
            }

            guard let user = result?.user,
                  let idToken = user.idToken?.tokenString else {
                self.isLoading = false
                print("❌ Missing Google ID Token")
                return
            }

            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: user.accessToken.tokenString
            )

            Auth.auth().signIn(with: credential) { authResult, error in
                if let error = error {
                    self.isLoading = false
                    self.handleAuthError(error, pendingCredential: credential)
                    return
                }
                DispatchQueue.main.async {
                    self.currentUser = authResult?.user
                    self.isLoading = false
                }
            }
        }
    }

    // MARK: - Email/Password

    func signInWithEmail(email: String, password: String) async {
        do {
            DispatchQueue.main.async { self.isLoading = true }
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            await MainActor.run {
                self.currentUser = result.user
                self.isLoading = false
                self.loadUserProfile(uid: result.user.uid)
            }
            print("✅ Signed in with email: \(result.user.uid)")
        } catch {
            await MainActor.run { self.isLoading = false }
            print("❌ Email sign-in error: \(error.localizedDescription)")
        }
    }

    func signUpWithEmail(email: String, password: String) async {
        do {
            DispatchQueue.main.async { self.isLoading = true }
            let result = try await Auth.auth().createUser(withEmail: email, password: password)

            let doc: [String: Any] = [
                "uid": result.user.uid,
                "displayName": email.split(separator: "@").first.map(String.init) ?? "User",
                "email": email,
                "photoURL": NSNull(),
                "friends": [],
                "incomingRequests": [],
                "outgoingRequests": [],
                "bio": NSNull()
            ]
            try await Firestore.firestore().collection("users").document(result.user.uid).setData(doc, merge: true)

            await MainActor.run {
                self.currentUser = result.user
                self.userProfile = UserProfile(
                    id: result.user.uid,
                    uid: result.user.uid,
                    displayName: doc["displayName"] as? String ?? "User",
                    email: email,
                    photoURL: nil,
                    friends: [],
                    incomingRequests: [],
                    outgoingRequests: [],
                    bio: nil
                )
                self.isLoading = false
            }
            print("✅ Signed up with email: \(result.user.uid)")
        } catch {
            await MainActor.run { self.isLoading = false }
            print("❌ Email sign-up error: \(error.localizedDescription)")
        }
    }

    // MARK: - Profile Mutations

    func updateBio(to newBio: String) async {
        guard let uid = Auth.auth().currentUser?.uid else {
            print("❌ No current user found for bio update")
            return
        }
        print("🔄 Updating bio for user \(uid) to: \(newBio)")
        do {
            try await Firestore.firestore().collection("users").document(uid)
                .setData(["bio": newBio], merge: true)
            await MainActor.run {
                self.userProfile?.bio = newBio
                print("✅ Bio updated locally to: \(newBio)")
            }
            print("✅ Bio updated in Firestore")
        } catch {
            print("❌ Failed to update bio: \(error.localizedDescription)")
        }
    }

    func updateDisplayName(to newDisplayName: String) async {
        guard let uid = Auth.auth().currentUser?.uid else {
            print("❌ No current user found for display name update")
            return
        }
        print("🔄 Updating display name for user \(uid) to: \(newDisplayName)")
        do {
            try await Firestore.firestore().collection("users").document(uid)
                .setData(["displayName": newDisplayName], merge: true)
            await MainActor.run {
                self.userProfile?.displayName = newDisplayName
                print("✅ Display name updated locally to: \(newDisplayName)")
            }
            print("✅ Display name updated in Firestore")
        } catch {
            print("❌ Failed to update display name: \(error.localizedDescription)")
        }
    }

    func loadSavedSpotsCount() async -> Int {
        guard let uid = Auth.auth().currentUser?.uid else {
            print("❌ No current user found for saved spots count")
            return 0
        }
        do {
            let snap = try await Firestore.firestore().collection("users").document(uid).getDocument()
            let data = snap.data() ?? [:]
            let saved = data["savedSpots"] as? [String] ?? []
            print("✅ Loaded saved spots count: \(saved.count)")
            return saved.count
        } catch {
            print("❌ Failed to load saved spots count: \(error.localizedDescription)")
            return 0
        }
    }

    // MARK: - Error & Linking (Firebase 12.x)

    private func handleAuthError(_ error: Error, pendingCredential: AuthCredential? = nil) {
        let nsErr = error as NSError

        // Only process Firebase Auth errors
        guard nsErr.domain == AuthErrorDomain,
              let authError = AuthErrorCode(_bridgedNSError: nsErr) else {
            print("❌ Non-Auth error: \(nsErr.localizedDescription)")
            return
        }

        let code = authError.code

        switch code {
        case .accountExistsWithDifferentCredential:
            let email = nsErr.userInfo[AuthErrorUserInfoEmailKey] as? String
            let updated = nsErr.userInfo[AuthErrorUserInfoUpdatedCredentialKey] as? AuthCredential ?? pendingCredential
            print("⚠️ Account exists with different credential. email=\(email ?? "nil")")
            if let updated { self.linkPendingCredentialAfterSignIn(updated) }

        case .wrongPassword, .invalidEmail, .userDisabled, .userNotFound:
            print("❌ Auth error (\(code)): \(nsErr.localizedDescription)")

        default:
            print("❌ Auth error (\(code)): \(nsErr.localizedDescription)")
        }
    }

    private func linkPendingCredentialAfterSignIn(_ credential: AuthCredential) {
        guard let user = Auth.auth().currentUser else {
            print("ℹ️ No current user to link credential to.")
            return
        }
        user.link(with: credential) { result, error in
            if let error = error {
                print("❌ Linking failed: \(error.localizedDescription)")
            } else if let linkedUser = result?.user {
                print("✅ Linking succeeded for user: \(linkedUser.uid)")
            } else {
                print("ℹ️ Linking finished with no result.")
            }
        }
    }

    // MARK: - Nonce helpers

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.map { String(format: "%02x", $0) }.joined()
    }

    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length

        while remaining > 0 {
            var random: UInt8 = 0
            let status = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
            if status != errSecSuccess { continue }
            result.append(charset[Int(random) % charset.count])
            remaining -= 1
        }
        return result
    }
}

// MARK: - UIWindowScene helper (file scope)

private extension UIWindowScene {
    var keyWindow: UIWindow? { windows.first(where: { $0.isKeyWindow }) }
}
