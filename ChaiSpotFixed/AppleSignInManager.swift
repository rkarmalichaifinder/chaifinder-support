// AppleSignInManager.swift
import Foundation
import AuthenticationServices
import CryptoKit
import FirebaseAuth
import UIKit

final class AppleSignInManager: NSObject, ObservableObject {
    @Published var appleUserID: String?
    private var currentNonce: String?
    private var completion: ((Result<AuthDataResult, Error>) -> Void)?
    private weak var anchor: ASPresentationAnchor?

    // Entry point used by SessionStore or your view
    func startSignIn(completion: @escaping (Result<AuthDataResult, Error>) -> Void) {
        self.completion = completion

        // Find a presentation anchor (works on iPhone & iPad)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let win = scene.windows.first(where: { $0.isKeyWindow }) {
            self.anchor = win
        }

        // 1) Prepare request with nonce
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        let nonce = randomNonceString()
        currentNonce = nonce
        request.nonce = sha256(nonce)

        // 2) Kick off Apple flow
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    // MARK: - Nonce helpers (per Firebase docs)
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var bytes = [UInt8](repeating: 0, count: length)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        precondition(status == errSecSuccess)
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(bytes.map { charset[Int($0) % charset.count] })
    }

    private func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let hashed = SHA256.hash(data: data)
        return hashed.map { String(format: "%02x", $0) }.joined()
    }
}

extension AppleSignInManager: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard
            let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
            let tokenData = credential.identityToken,
            let idToken = String(data: tokenData, encoding: .utf8),
            let nonce = currentNonce
        else {
            completion?(.failure(NSError(domain: "AppleAuth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing Apple token/nonce."])))
            completion = nil
            return
        }

        // Keep userID around if you need it for your own logic
        let userID = credential.user
        UserDefaults.standard.set(userID, forKey: "appleUserID")
        DispatchQueue.main.async { self.appleUserID = userID }

        // 3) Build Firebase credential for Apple (Firebase 12.x API)
        let firebaseCred = OAuthProvider.appleCredential(
            withIDToken: idToken,
            rawNonce: nonce,
            fullName: credential.fullName // only non-nil on very first consent
        )

        // 4) Sign in to Firebase
        Auth.auth().signIn(with: firebaseCred) { authResult, error in
            if let error = error {
                self.completion?(.failure(error))
            } else if let authResult = authResult {
                // Optional: set displayName on first sign-in if Apple returned it
                if let name = credential.fullName, (name.givenName != nil || name.familyName != nil) {
                    let display = [name.givenName, name.familyName].compactMap { $0 }.joined(separator: " ")
                    let change = authResult.user.createProfileChangeRequest()
                    change.displayName = display.isEmpty ? nil : display
                    change.commitChanges(completion: nil)
                }
                self.completion?(.success(authResult))
            }
            self.completion = nil
            self.currentNonce = nil
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        completion?(.failure(error))
        completion = nil
        currentNonce = nil
    }
}

extension AppleSignInManager: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        anchor ?? ASPresentationAnchor()
    }
}
