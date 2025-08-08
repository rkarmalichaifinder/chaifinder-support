import SwiftUI
import Firebase
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore

struct EmailLoginView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var showError = false

    var body: some View {
        VStack(spacing: 16) {
            Text("Sign in with Email")
                .font(.title2)

            TextField("Email", text: $email)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .disabled(isLoading)

            SecureField("Password", text: $password)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .disabled(isLoading)

            Button(action: signIn) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text("Log In")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isLoading || email.isEmpty || password.isEmpty)

            Button(action: signUp) {
                Text("Create Account")
            }
            .buttonStyle(.bordered)
            .disabled(isLoading || email.isEmpty || password.isEmpty)

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

    private func signIn() {
        guard !email.isEmpty && !password.isEmpty else {
            handleError("Please enter both email and password")
            return
        }
        
        // Check if Firebase is initialized before accessing Auth
        if FirebaseApp.app() == nil {
            handleError("Authentication service not available")
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Auth.auth().signIn(withEmail: email, password: password) { result, error in
            DispatchQueue.main.async {
                isLoading = false
                
                if let error = error {
                    handleError("Login failed: \(error.localizedDescription)")
                } else {
                    errorMessage = nil
                    print("✅ Email login successful")
                }
            }
        }
    }

    private func signUp() {
        guard !email.isEmpty && !password.isEmpty else {
            handleError("Please enter both email and password")
            return
        }
        
        guard password.count >= 6 else {
            handleError("Password must be at least 6 characters")
            return
        }
        
        // Check if Firebase is initialized before accessing Auth
        if FirebaseApp.app() == nil {
            handleError("Authentication service not available")
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Auth.auth().createUser(withEmail: email, password: password) { result, error in
            DispatchQueue.main.async {
                isLoading = false
                
                if let error = error {
                    handleError("Signup failed: \(error.localizedDescription)")
                } else {
                    errorMessage = nil
                    print("✅ Email signup successful")
                }
            }
        }
    }
    
    private func handleError(_ message: String) {
        DispatchQueue.main.async {
            isLoading = false
            errorMessage = message
            showError = true
            print("❌ Email Authentication Error: \(message)")
        }
    }
}
