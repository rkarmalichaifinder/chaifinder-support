import SwiftUI
import FirebaseAuth

struct SignInView: View {
    @StateObject private var sessionStore = SessionStore()
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var isSignUp = false
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var showSuccessAlert = false
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationView {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 20) {
                        // Logo and Title
                        VStack(spacing: 16) {
                            Image(systemName: "cup.and.saucer.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.orange)

                            Text("ChaiSpot")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)

                            Text("Find the best chai spots near you")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 40)
                        .id("top")

                        // Sign In/Up Form
                        VStack(spacing: 16) {
                            if isSignUp {
                                TextField("Display Name", text: $displayName)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .autocapitalization(.words)
                                    .focused($isFocused)
                                    .onChange(of: displayName) { _ in errorMessage = nil }
                            }

                            TextField("Email", text: $email)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .focused($isFocused)
                                .onChange(of: email) { _ in errorMessage = nil }

                            SecureField("Password", text: $password)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .focused($isFocused)
                                .onChange(of: password) { _ in errorMessage = nil }

                            if let errorMessage = errorMessage {
                                Text(errorMessage)
                                    .foregroundColor(.red)
                                    .font(.caption)
                                    .multilineTextAlignment(.center)
                            }

                            Button(action: handleAuthentication) {
                                HStack {
                                    if isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(0.8)
                                    }
                                    Text(isSignUp ? "Sign Up" : "Sign In")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.orange)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                            }
                            .disabled(isLoading)

                            Button(action: { isSignUp.toggle() }) {
                                Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                                    .foregroundColor(.orange)
                                    .font(.caption)
                            }
                        }
                        .padding(.horizontal, 32)

                        Spacer(minLength: 100)
                    }
                }
                .navigationBarHidden(true)
                .onTapGesture {
                    isFocused = false
                }
                .onChange(of: isFocused) { focused in
                    if focused {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo("top", anchor: .top)
                        }
                    }
                }
            }
        }
        .environmentObject(sessionStore)
        .alert("✅ Successfully \(isSignUp ? "signed up" : "signed in")", isPresented: $showSuccessAlert) {
            Button("Continue") { }
        }
    }

    private func handleAuthentication() {
        isLoading = true
        errorMessage = nil

        // Basic input validation
        if email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
           password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errorMessage = "Email and password are required"
            isLoading = false
            return
        }

        if isSignUp && displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errorMessage = "Display name is required"
            isLoading = false
            return
        }

        if isSignUp {
            sessionStore.signUp(email: email, password: password, displayName: displayName) { success, error in
                DispatchQueue.main.async {
                    isLoading = false
                    if success {
                        showSuccessAlert = true
                    } else {
                        errorMessage = error ?? "Sign up failed"
                    }
                }
            }
        } else {
            sessionStore.signIn(email: email, password: password) { success, error in
                DispatchQueue.main.async {
                    isLoading = false
                    if success {
                        showSuccessAlert = true
                    } else {
                        errorMessage = error ?? "Sign in failed"
                    }
                }
            }
        }
    }
}

struct SignInView_Previews: PreviewProvider {
    static var previews: some View {
        SignInView()
    }
}
