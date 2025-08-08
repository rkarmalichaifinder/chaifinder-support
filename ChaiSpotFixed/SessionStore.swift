import SwiftUI
import FirebaseAuth
import FirebaseCore
import AuthenticationServices
import CryptoKit
import FirebaseFirestore
import GoogleSignIn

class SessionStore: NSObject, ObservableObject {
    @Published var currentUser: User?
    @Published var userProfile: UserProfile?
    @Published var isLoading = true // Start with true, only set to false when we have a definitive state
    private var authStateListener: AuthStateDidChangeListenerHandle?
    private var didInitialize = false // Track if we've initialized
    private var didAttachListener = false // Track if we've attached the listener
    fileprivate var currentNonce: String?

    override init() {
        super.init()
        // Don't initialize Firebase Auth immediately - wait until needed
        print("✅ SessionStore initialized without Firebase Auth")
    }
    
    func initializeIfNeeded() {
        guard !didInitialize else { 
            print("⚙️ Already initialized, skipping")
            return 
        }
        
        didInitialize = true
        
        print("🔄 Initializing Firebase Auth...")
        
        // Set loading state immediately
        DispatchQueue.main.async {
            self.isLoading = true
        }
        
        // Don't check current user state during initialization - do it later
        DispatchQueue.main.async {
            print("✅ Firebase Auth initialized successfully")
        }
    }
    
    // Separate method to set up Auth listener when needed
    func setupAuthListener() {
        guard !didAttachListener else { 
            print("👂 Already attached listener, skipping")
            return 
        }
        
        didAttachListener = true
        print("👂 Attaching auth listener")

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            // First, check the current user state immediately
            let currentUser = Auth.auth().currentUser
            DispatchQueue.main.async {
                if let user = currentUser {
                    print("👤 Found current user during listener setup: \(user.email ?? "unknown")")
                    self?.currentUser = user
                    self?.loadUserProfile(uid: user.uid)
                } else {
                    print("👤 No current user found during listener setup")
                }
            }
            
            // Then attach the listener for future changes
            let listener = Auth.auth().addStateDidChangeListener { [weak self] auth, user in
                DispatchQueue.main.async {
                    self?.currentUser = user
                    if let user = user {
                        self?.loadUserProfile(uid: user.uid)
                    } else {
                        self?.userProfile = nil
                    }
                    // Always set loading to false when auth state changes
                    self?.isLoading = false
                    print("👤 Auth state changed. user: \(user?.uid ?? "nil")")
                }
            }
            
            DispatchQueue.main.async {
                self?.authStateListener = listener
                print("✅ Auth listener set up successfully")
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
            
            guard let document = snapshot, document.exists else {
                // Auto-create a basic user profile document so edits can persist
                let email = Auth.auth().currentUser?.email ?? "unknown"
                let display = email.components(separatedBy: "@").first ?? "User"
                let newProfile = [
                    "uid": uid,
                    "displayName": display,
                    "email": email,
                    "friends": [],
                    "incomingRequests": [],
                    "outgoingRequests": []
                ] as [String : Any]
                Firestore.firestore().collection("users").document(uid).setData(newProfile, merge: true) { err in
                    if let err = err {
                        print("❌ Failed to auto-create user profile: \(err.localizedDescription)")
                        return
                    }
                    print("✅ Auto-created user profile for \(uid)")
                    // Reload after creation
                    self.loadUserProfile(uid: uid)
                }
                return
            }
            
            let data = document.data() ?? [:]
            let userProfile = UserProfile(
                id: document.documentID,
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
                self.userProfile = userProfile
                print("✅ User profile loaded with bio: \(userProfile.bio ?? "nil")")
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
            await MainActor.run {
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
            await MainActor.run {
                self.currentUser = result.user
                self.userProfile = newUser
            }
            print("✅ Signed up with email: \(result.user.uid)")
        } catch {
            print("❌ Email sign-up error: \(error.localizedDescription)")
        }
    }

    func updateBio(to newBio: String) async {
        guard let uid = Auth.auth().currentUser?.uid else { 
            print("❌ No current user found for bio update")
            return 
        }

        print("🔄 Updating bio for user \(uid) to: \(newBio)")
        
        let db = Firestore.firestore()
        let ref = db.collection("users").document(uid)

        do {
            try await ref.setData(["bio": newBio], merge: true)
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
        
        let db = Firestore.firestore()
        let ref = db.collection("users").document(uid)

        do {
            try await ref.setData(["displayName": newDisplayName], merge: true)
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

        let db = Firestore.firestore()
        let ref = db.collection("users").document(uid)

        do {
            let snapshot = try await ref.getDocument()
            guard let data = snapshot.data() else {
                print("❌ No user data found for saved spots count")
                return 0
            }
            
            let savedSpotIds = data["savedSpots"] as? [String] ?? []
            print("✅ Loaded saved spots count: \(savedSpotIds.count)")
            return savedSpotIds.count
        } catch {
            print("❌ Failed to load saved spots count: \(error.localizedDescription)")
            return 0
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
