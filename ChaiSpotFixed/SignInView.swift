import SwiftUI
import AuthenticationServices
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import CryptoKit

struct SignInView: View {
    @EnvironmentObject var session: SessionStore
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var currentNonce: String?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                
                Text("Welcome to Chai Spot")
                    .font(.title)
                    .multilineTextAlignment(.center)
                
                // Apple Sign-In
                SignInWithAppleButton(
                    .signIn,
                    onRequest: { request in
                        request.requestedScopes = [.fullName, .email]
                        currentNonce = randomNonceString()
                        request.nonce = sha256(currentNonce!)
                        
                        print("🔧 Apple Sign-In Request:")
                        print("🔧 Bundle ID: \(Bundle.main.bundleIdentifier ?? "unknown")")
                        print("🔧 Requested Scopes: \(request.requestedScopes?.map { $0.rawValue } ?? [])")
                        print("🔧 Nonce: \(currentNonce ?? "nil")")
                    },
                    onCompletion: handleAppleSignIn
                )
                .signInWithAppleButtonStyle(.black)
                .frame(height: 50)
                .cornerRadius(8)
                .disabled(isLoading)
                
                // Google Sign-In
                Button(action: startGoogleSignIn) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "globe")
                        }
                        Text("Sign in with Google")
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.white)
                    .foregroundColor(.black)
                    .cornerRadius(8)
                    .shadow(radius: 2)
                }
                .disabled(isLoading)
                
                // Email Sign-In
                NavigationLink("Sign in with Email") {
                    EmailLoginView()
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.white)
                    .foregroundColor(.black)
                    .cornerRadius(8)
                    .shadow(radius: 2)
                    .disabled(isLoading)
                
                if let errorMessage = errorMessage {
                    Text("⚠️ \(errorMessage)")
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                }
                
                Spacer()
            }
            .padding()
            .alert("Authentication Error", isPresented: $showError) {
                Button("OK") {
                    errorMessage = nil
                    showError = false
                }
            } message: {
                Text(errorMessage ?? "An unknown error occurred")
            }
        }
    }
    
    // MARK: - Apple Sign-In Handler
    func handleAppleSignIn(result: Result<ASAuthorization, Error>) {
        isLoading = true
        errorMessage = nil
        
        switch result {
        case .success(let authResults):
            if let appleIDCredential = authResults.credential as? ASAuthorizationAppleIDCredential {
                guard let tokenData = appleIDCredential.identityToken,
                      let tokenStr = String(data: tokenData, encoding: .utf8) else {
                    handleError("Failed to get Apple identity token")
                    return
                }
                
                guard let nonce = currentNonce else {
                    handleError("Missing nonce for Apple sign-in")
                    return
                }
                
                print("🔧 Apple Sign-In - Got identity token, creating Firebase credential")
                print("🔧 Bundle ID: \(Bundle.main.bundleIdentifier ?? "unknown")")
                print("🔧 User ID: \(appleIDCredential.user)")
                print("🔧 Email: \(appleIDCredential.email ?? "no email")")
                print("🔧 Full Name: \(appleIDCredential.fullName?.description ?? "no name")")
                
                let credential = OAuthProvider.credential(
                    withProviderID: "apple.com",
                    idToken: tokenStr,
                    rawNonce: nonce
                )
                
                Auth.auth().signIn(with: credential) { result, error in
                    DispatchQueue.main.async {
                        isLoading = false
                        
                        if let error = error {
                            print("❌ Apple Firebase auth error: \(error.localizedDescription)")
                            print("❌ Error code: \((error as NSError).code)")
                            print("❌ Error domain: \((error as NSError).domain)")
                            
                            // Provide more specific error messages
                            let nsError = error as NSError
                            if nsError.domain == "FIRAuthErrorDomain" {
                                switch nsError.code {
                                case 17020:
                                    handleError("Apple Sign-In failed: Invalid ID token. Please try again.")
                                case 17021:
                                    handleError("Apple Sign-In failed: User account not found. Please try again.")
                                default:
                                    handleError("Apple Sign-In failed: \(error.localizedDescription)")
                                }
                            } else {
                                handleError("Apple Sign-In failed: \(error.localizedDescription)")
                            }
                        } else if let result = result {
                            print("✅ Apple sign-in successful for user: \(result.user.uid)")
                            createUserProfileIfNeeded(for: result.user)
                        }
                    }
                }
            } else {
                handleError("Invalid Apple credential")
            }
            
        case .failure(let error):
            print("❌ Apple authorization error: \(error.localizedDescription)")
            print("❌ Error code: \((error as NSError).code)")
            print("❌ Error domain: \((error as NSError).domain)")
            
            // Handle specific Apple Sign-In errors
            let nsError = error as NSError
            if nsError.domain == "com.apple.AuthenticationServices.AuthorizationError" {
                switch nsError.code {
                case 1000:
                    // This is likely a simulator issue or Firebase Console configuration issue
                    handleError("Apple Sign-In failed: This might be a simulator limitation. Please try on a physical device or use Email Sign-In.")
                case 1001:
                    handleError("Apple Sign-In failed: User cancelled the authorization.")
                case 1002:
                    handleError("Apple Sign-In failed: Invalid response from Apple.")
                case 1003:
                    handleError("Apple Sign-In failed: Not authorized.")
                case 1004:
                    handleError("Apple Sign-In failed: Unknown error occurred.")
                default:
                    handleError("Apple Sign-In failed: \(error.localizedDescription)")
                }
            } else {
                handleError("Apple authorization failed: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Google Sign-In Handler
    func startGoogleSignIn() {
        isLoading = true
        errorMessage = nil
        
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            handleError("Missing Firebase client ID")
            return
        }
        
        print("🔧 Starting Google Sign-In with client ID: \(clientID)")
        
        // For now, let's use a simple approach - just show an error message
        // indicating that Google Sign-In needs to be configured properly
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.handleError("Google Sign-In is currently being configured. Please use Apple Sign-In or Email Sign-In for now.")
        }
    }
    
    // MARK: - Error Handling
    private func handleError(_ message: String) {
        DispatchQueue.main.async {
            isLoading = false
            errorMessage = message
            showError = true
            print("❌ Authentication Error: \(message)")
        }
    }
    
    // MARK: - Firestore User Profile Setup
    func createUserProfileIfNeeded(for user: User) {
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(user.uid)
        
        userRef.getDocument { document, error in
            if let error = error {
                print("❌ Failed to fetch user profile: \(error.localizedDescription)")
                return
            }
            
            // Always enforce that uid is correct in the document
            let displayName = user.displayName ?? "Chai Fan"
            let email = user.email ?? ""
            let photoURL = user.photoURL?.absoluteString ?? ""
            
            let newUserData: [String: Any] = [
                "uid": user.uid, // 🔒 enforced match to Auth UID
                "displayName": displayName,
                "email": email,
                "photoURL": photoURL,
                "bio": "",
                "friends": [],
                "incomingRequests": [],
                "outgoingRequests": [],
                "savedSpots": [],
                "createdAt": FieldValue.serverTimestamp()
            ]
            
            userRef.setData(newUserData, merge: true) { error in
                if let error = error {
                    print("❌ Failed to create/update user profile: \(error.localizedDescription)")
                } else {
                    print("✅ User profile written for \(user.uid)")
                }
            }
        }
    }
    
    // MARK: - Security Helpers
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] =
        Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        
        while remainingLength > 0 {
            let randoms: [UInt8] = (0 ..< 16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
                }
                return random
            }
            
            randoms.forEach { random in
                if remainingLength == 0 {
                    return
                }
                
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        
        return result
    }
    
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        
        return hashString
    }
}
