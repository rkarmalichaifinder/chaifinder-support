import SwiftUI
import FirebaseAuth

struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage = ""

    var body: some View {
        VStack(spacing: 20) {
            Text("Chai Finder")
                .font(.largeTitle)
                .bold()

            TextField("Email", text: $email)
                .autocapitalization(.none)
                .keyboardType(.emailAddress)
                .textFieldStyle(RoundedBorderTextFieldStyle())

            SecureField("Password", text: $password)
                .textFieldStyle(RoundedBorderTextFieldStyle())

            Button("Log In") {
                login()
            }
            .buttonStyle(.borderedProminent)

            if !errorMessage.isEmpty {
                Text("❌ \(errorMessage)")
                    .foregroundColor(.red)
            }
        }
        .padding()
    }

    private func login() {
        Auth.auth().signIn(withEmail: email, password: password) { result, error in
            if let error = error {
                self.errorMessage = error.localizedDescription
            } else {
                self.errorMessage = ""
            }
        }
    }
}
