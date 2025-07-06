import SwiftUI
import AuthenticationServices
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore

struct SignInView: View {
    @EnvironmentObject var session: SessionStore
    @State private var authSession: ASWebAuthenticationSession?
    @State private var contextProvider = WebAuthContextProvider()
    
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
                    },
                    onCompletion: handleAppleSignIn
                )
                .signInWithAppleButtonStyle(.black)
                .frame(height: 50)
                .cornerRadius(8)
                
                // Google Sign-In
                Button(action: startGoogleOAuth) {
                    HStack {
                        Image(systemName: "globe")
                        Text("Sign in with Google")
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.white)
                    .foregroundColor(.black)
                    .cornerRadius(8)
                    .shadow(radius: 2)
                }
                
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
                
                Spacer()
            }
            .padding()
        }
    }
    
    // MARK: - Apple Sign-In Handler
    func handleAppleSignIn(result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authResults):
            if let appleIDCredential = authResults.credential as? ASAuthorizationAppleIDCredential {
                guard let tokenData = appleIDCredential.identityToken,
                      let tokenStr = String(data: tokenData, encoding: .utf8) else {
                    print("Failed to get identity token")
                    return
                }
                
                let credential = OAuthProvider.credential(
                    withProviderID: "apple.com",
                    idToken: tokenStr,
                    rawNonce: nil
                )
                
                Auth.auth().signIn(with: credential) { result, error in
                    if let error = error {
                        print("Apple sign-in failed:", error)
                    } else if let result = result {
                        print("Apple sign-in successful")
                        createUserProfileIfNeeded(for: result.user)
                    }
                }
            }
            
        case .failure(let error):
            print("Authorization failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Google Sign-In via OAuth
    func startGoogleOAuth() {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            print("Missing Firebase client ID")
            return
        }
        
        let redirectURI = "com.googleusercontent.apps.\(clientID):/oauthredirect"
        let encodedRedirect = redirectURI.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        let authURLString = """
        https://accounts.google.com/o/oauth2/v2/auth?client_id=\(clientID)&redirect_uri=\(encodedRedirect)&response_type=token&scope=email%20profile
        """
        
        guard let authURL = URL(string: authURLString) else {
            print("Invalid Google Auth URL")
            return
        }
        
        authSession = ASWebAuthenticationSession(
            url: authURL,
            callbackURLScheme: "com.googleusercontent.apps.\(clientID)"
        ) { callbackURL, error in
            if let error = error {
                print("Google auth failed: \(error)")
                return
            }
            
            guard let callbackURL = callbackURL,
                  let fragment = callbackURL.fragment,
                  let accessToken = fragment
                .components(separatedBy: "&")
                .first(where: { $0.hasPrefix("access_token=") })?
                .replacingOccurrences(of: "access_token=", with: "") else {
                print("Missing access token")
                return
            }
            
            let firebaseCredential = GoogleAuthProvider.credential(withIDToken: accessToken, accessToken: accessToken)
            
            Auth.auth().signIn(with: firebaseCredential) { result, error in
                if let error = error {
                    print("Firebase Google login failed: \(error)")
                } else if let result = result {
                    print("Google sign-in successful")
                    createUserProfileIfNeeded(for: result.user)
                }
            }
        }
        
        authSession?.presentationContextProvider = contextProvider
        authSession?.prefersEphemeralWebBrowserSession = true
        authSession?.start()
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
