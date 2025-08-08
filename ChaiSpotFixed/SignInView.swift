import SwiftUI
import FirebaseAuth
import FirebaseCore
import GoogleSignIn
import AuthenticationServices

struct SignInView: View {
    @EnvironmentObject var sessionStore: SessionStore
    @Environment(\.colorScheme) var colorScheme
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage: String?
    @State private var showingSignUp = false
    @State private var showingTerms = false
    @State private var hasAcceptedTerms = false

    var body: some View {
        NavigationView {
            VStack(spacing: DesignSystem.Spacing.xl) {
                Spacer()

                Text("Chai Finder")
                    .font(DesignSystem.Typography.titleLarge)
                    .bold()

                VStack(spacing: DesignSystem.Spacing.lg) {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .padding(DesignSystem.Spacing.lg)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(DesignSystem.CornerRadius.medium)
                        .font(DesignSystem.Typography.bodyMedium)

                    SecureField("Password", text: $password)
                        .padding(DesignSystem.Spacing.lg)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(DesignSystem.CornerRadius.medium)
                        .font(DesignSystem.Typography.bodyMedium)
                }
                .iPadOptimized()

                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(DesignSystem.Typography.bodySmall)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                }

                VStack(spacing: DesignSystem.Spacing.md) {
                    Button(action: {
                        Task {
                            errorMessage = nil
                            await sessionStore.signInWithEmail(email: email, password: password)
                        }
                    }) {
                        HStack {
                            Text("Sign In")
                                .font(DesignSystem.Typography.bodyMedium)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(DesignSystem.Spacing.lg)
                        .background(Color.orange)
                        .cornerRadius(DesignSystem.CornerRadius.medium)
                    }

                    Button("Don't have an account? Sign Up") {
                        showingTerms = true
                    }
                    .font(DesignSystem.Typography.bodyMedium)
                    .padding(.top, DesignSystem.Spacing.sm)
                }
                .iPadOptimized()

                Divider()
                    .padding(.vertical, DesignSystem.Spacing.lg)

                // Google Sign-In
                Button(action: {
                    sessionStore.signInWithGoogle()
                }) {
                    HStack {
                        Image(systemName: "globe")
                            .font(.system(size: UIDevice.current.userInterfaceIdiom == .pad ? 20 : 16))
                        Text("Sign in with Google")
                            .font(DesignSystem.Typography.bodyMedium)
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(DesignSystem.Spacing.lg)
                    .background(Color(.systemGray5))
                    .cornerRadius(DesignSystem.CornerRadius.medium)
                }
                .iPadOptimized()

                // Apple Sign-In - Temporarily hidden
                /*
                Button(action: {
                    sessionStore.signInWithApple()
                }) {
                    HStack {
                        Image(systemName: "applelogo")
                        Text("Sign in with Apple")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                */

                Spacer()
            }
            .padding(DesignSystem.Spacing.xl)
            .navigationTitle("Welcome")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingTerms) {
                TermsOfServiceView(hasAcceptedTerms: $hasAcceptedTerms)
            }
            .onChange(of: hasAcceptedTerms) { accepted in
                if accepted {
                    showingSignUp = true
                    hasAcceptedTerms = false // Reset for next time
                }
            }
            .sheet(isPresented: $showingSignUp) {
                SignUpView()
                    .environmentObject(sessionStore)
            }
        }
    }
}

struct SignUpView: View {
    @EnvironmentObject var sessionStore: SessionStore
    @Environment(\.dismiss) var dismiss
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)

                SecureField("Password", text: $password)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)

                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Button("Create Account") {
                    Task {
                        errorMessage = nil
                        await sessionStore.signUpWithEmail(email: email, password: password)
                        if sessionStore.currentUser != nil {
                            dismiss()
                        }
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.orange)
                .cornerRadius(8)

                Spacer()
            }
            .padding()
            .navigationTitle("Sign Up")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}
