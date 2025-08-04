import SwiftUI
import AuthenticationServices
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import CryptoKit

struct SignInView: View {
    @EnvironmentObject var session: SessionStore
    @State private var authSession: ASWebAuthenticationSession?
    @State private var contextProvider = WebAuthContextProvider()
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
                    },
                    onCompletion: handleAppleSignIn
                )
                .signInWithAppleButtonStyle(.black)
                .frame(height: 50)
                .cornerRadius(8)
                .disabled(isLoading)
                
                // Google Sign-In
                Button(action: startGoogleOAuth) {
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
                            handleError("Apple sign-in failed: \(error.localizedDescription)")
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
            handleError("Apple authorization failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Google Sign-In via OAuth
    func startGoogleOAuth() {
        isLoading = true
        errorMessage = nil
        
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            handleError("Missing Firebase client ID")
            return
        }
        
        print("🔧 Starting Google OAuth with client ID: \(clientID)")
        
        // Use the correct URL scheme from Info.plist
        let redirectURI = "com.googleusercontent.apps.587784566464-a20p386bmiuvgaigq61snprnbb0fqios:/oauthredirect"
        let encodedRedirect = redirectURI.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        let authURLString = """
        https://accounts.google.com/o/oauth2/v2/auth?client_id=\(clientID)&redirect_uri=\(encodedRedirect)&response_type=code&scope=email%20profile&access_type=offline
        """
        
        guard let authURL = URL(string: authURLString) else {
            handleError("Invalid Google Auth URL")
            return
        }
        
        print("🔧 Google OAuth URL: \(authURL)")
        
        authSession = ASWebAuthenticationSession(
            url: authURL,
            callbackURLScheme: "com.googleusercontent.apps.587784566464-a20p386bmiuvgaigq61snprnbb0fqios"
        ) { callbackURL, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Google OAuth error: \(error.localizedDescription)")
                    handleError("Google auth failed: \(error.localizedDescription)")
                    return
                }
                
                guard let callbackURL = callbackURL else {
                    handleError("No callback URL received from Google")
                    return
                }
                
                print("🔧 Google OAuth callback URL: \(callbackURL)")
                
                // Extract authorization code from callback URL
                guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                      let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
                    handleError("Missing authorization code from Google")
                    return
                }
                
                print("🔧 Got authorization code from Google")
                
                // Exchange authorization code for tokens
                exchangeCodeForTokens(authorizationCode: code, clientID: clientID)
            }
        }
        
        authSession?.presentationContextProvider = contextProvider
        authSession?.prefersEphemeralWebBrowserSession = true
        authSession?.start()
    }
    
    // MARK: - Exchange Authorization Code for Tokens
    private func exchangeCodeForTokens(authorizationCode: String, clientID: String) {
        let tokenURL = URL(string: "https://oauth2.googleapis.com/token")!
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let redirectURI = "com.googleusercontent.apps.587784566464-a20p386bmiuvgaigq61snprnbb0fqios:/oauthredirect"
        let body = "client_id=\(clientID)&code=\(authorizationCode)&grant_type=authorization_code&redirect_uri=\(redirectURI)"
        request.httpBody = body.data(using: .utf8)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Token exchange error: \(error.localizedDescription)")
                    handleError("Failed to exchange code for tokens: \(error.localizedDescription)")
                    return
                }
                
                guard let data = data else {
                    handleError("No data received from token exchange")
                    return
                }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        print("🔧 Token exchange response: \(json)")
                        
                        guard let idToken = json["id_token"] as? String else {
                            handleError("Missing ID token from Google")
                            return
                        }
                        
                        // Create Firebase credential with ID token
                        let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: "")
                        
                        Auth.auth().signIn(with: credential) { result, error in
                            DispatchQueue.main.async {
                                isLoading = false
                                
                                if let error = error {
                                    print("❌ Firebase Google auth error: \(error.localizedDescription)")
                                    handleError("Firebase Google login failed: \(error.localizedDescription)")
                                } else if let result = result {
                                    print("✅ Google sign-in successful for user: \(result.user.uid)")
                                    createUserProfileIfNeeded(for: result.user)
                                }
                            }
                        }
                    }
                } catch {
                    print("❌ JSON parsing error: \(error.localizedDescription)")
                    handleError("Failed to parse token response")
                }
            }
        }.resume()
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
    
    // MARK: - Web Auth Context Provider
    class WebAuthContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
        func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
            UIApplication.shared
                .connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow } ?? UIWindow()
        }
    }
}
