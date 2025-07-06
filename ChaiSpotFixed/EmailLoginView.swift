import SwiftUI
import FirebaseAuth

struct EmailLoginView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage: String?

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

            SecureField("Password", text: $password)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)

            Button("Log In") {
                signIn()
            }
            .buttonStyle(.borderedProminent)

            Button("Create Account") {
                signUp()
            }
            .buttonStyle(.bordered)

            if let errorMessage = errorMessage {
                Text("⚠️ \(errorMessage)")
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .padding()
    }

    private func signIn() {
        Auth.auth().signIn(withEmail: email, password: password) { result, error in
            if let error = error {
                self.errorMessage = "Login failed: \(error.localizedDescription)"
            } else {
                self.errorMessage = nil
            }
        }
    }

    private func signUp() {
        Auth.auth().createUser(withEmail: email, password: password) { result, error in
            if let error = error {
                self.errorMessage = "Signup failed: \(error.localizedDescription)"
            } else {
                self.errorMessage = nil
            }
        }
    }
}
