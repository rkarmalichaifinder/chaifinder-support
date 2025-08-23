import SwiftUI

struct OnboardingExplainerView: View {
    @EnvironmentObject var session: SessionStore
    @State private var showingEmailSignIn = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var currentPage = 0
    @State private var showingPrivacyPolicy = false

    var body: some View {
        VStack(spacing: 24) {
            // Progress indicator
            HStack {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(index == currentPage ? DesignSystem.Colors.primary : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                        .animation(.easeInOut(duration: 0.3), value: currentPage)
                }
            }
            .padding(.top)
            
            Pager(content: [
                ExplainerCard(title: "Your chai, your way",
                              subtitle: "We personalize your map using your taste preferences.",
                              icon: "heart.fill"),
                ExplainerCard(title: "Friends make it better",
                              subtitle: "See spots your friends actually love.",
                              icon: "person.3.fill"),
                ExplainerCard(title: "Trusted community",
                              subtitle: "Identity helps keep reviews real and limit spam.",
                              icon: "shield.checkered")
            ], onPageChange: { page in
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentPage = page
                }
            })

            VStack(spacing: 12) {
                // All three sign-in methods with equal treatment
                // Apple Sign-In listed first for App Store compliance
                SignInWithAppleButton { 
                    signInWithApple()
                }
                .disabled(isLoading)
                
                SignInWithGoogleButton { 
                    signInWithGoogle()
                }
                .disabled(isLoading)
                
                SignInWithEmailButton { 
                    showingEmailSignIn = true
                }
                .disabled(isLoading)
                
                // Error message
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .transition(.opacity.combined(with: .scale))
                }
                
                // Privacy policy link
                Button("Learn about privacy") {
                    showingPrivacyPolicy = true
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 8)
            }
            .padding(.horizontal, 24)
        }
        .padding(.vertical, 32)
        .sheet(isPresented: $showingEmailSignIn) {
            EmailLoginView()
                .environmentObject(session)
        }
        .sheet(isPresented: $showingPrivacyPolicy) {
            PrivacyPolicyView()
        }
        .overlay(
            // Loading overlay
            Group {
                if isLoading {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.2)
                            Text("Signing you in...")
                                .font(.subheadline)
                                .foregroundColor(.white)
                        }
                        .padding(24)
                        .background(.ultraThinMaterial)
                        .cornerRadius(16)
                    }
                    .transition(.opacity)
                }
            }
        )
        .animation(.easeInOut(duration: 0.3), value: isLoading)
        .animation(.easeInOut(duration: 0.3), value: errorMessage)
    }
    
    private func signInWithApple() {
        isLoading = true
        errorMessage = nil
        
        session.signInWithApple { success in
            DispatchQueue.main.async {
                isLoading = false
                if !success {
                    errorMessage = "Apple Sign-In failed. Please try again."
                }
            }
        }
    }
    
    private func signInWithGoogle() {
        isLoading = true
        errorMessage = nil
        
        session.signInWithGoogle { success in
            DispatchQueue.main.async {
                isLoading = false
                if !success {
                    errorMessage = "Google Sign-In failed. Please try again."
                }
            }
        }
    }
}

private struct ExplainerCard: View {
    let title: String
    let subtitle: String
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: icon)
                    .font(.title)
                    .foregroundColor(DesignSystem.Colors.primary)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(nil)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

// Properly styled sign-in buttons with equal treatment
struct SignInWithAppleButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: "applelogo")
                    .font(.system(size: 16, weight: .medium))
                Text("Continue with Apple")
                    .font(.system(size: 16, weight: .medium))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.black)
            .cornerRadius(8)
        }
    }
}

struct SignInWithGoogleButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: "globe")
                    .font(.system(size: 16, weight: .medium))
                Text("Continue with Google")
                    .font(.system(size: 16, weight: .medium))
            }
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
            .cornerRadius(8)
        }
    }
}

struct SignInWithEmailButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: "envelope")
                    .font(.system(size: 16, weight: .medium))
                Text("Continue with Email")
                    .font(.system(size: 16, weight: .medium))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.blue)
            .cornerRadius(8)
        }
    }
}

// Enhanced Pager implementation with page change callback
struct Pager<Content: View>: View {
    let content: [Content]
    let onPageChange: ((Int) -> Void)?
    @State private var currentIndex = 0
    
    init(content: [Content], onPageChange: ((Int) -> Void)? = nil) {
        self.content = content
        self.onPageChange = onPageChange
    }
    
    var body: some View {
        TabView(selection: $currentIndex) {
            ForEach(0..<content.count, id: \.self) { index in
                content[index]
                    .tag(index)
            }
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
        .frame(height: 200)
        .onChange(of: currentIndex) { newIndex in
            onPageChange?(newIndex)
        }
    }
}

// MARK: - Privacy Policy View
struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Group {
                        PrivacySection(
                            title: "Data Collection",
                            content: "We collect only the information necessary to provide you with a personalized chai experience. This includes your taste preferences, location data (with your permission), and social connections."
                        )
                        
                        PrivacySection(
                            title: "How We Use Your Data",
                            content: "Your data is used to: personalize chai recommendations, connect you with friends, and improve our service. We never sell your personal information to third parties."
                        )
                        
                        PrivacySection(
                            title: "Review Privacy Controls",
                            content: "You have full control over who sees your reviews: Public (everyone), Friends Only (just your connections), or Private (only you). Change these settings anytime in Privacy Settings."
                        )
                        
                        PrivacySection(
                            title: "Data Security",
                            content: "We use industry-standard encryption and security measures to protect your data. All data is stored securely and access is strictly controlled."
                        )
                        
                        PrivacySection(
                            title: "Your Rights",
                            content: "You have the right to access, modify, or delete your data at any time. You can also opt out of data collection for personalization while still using the app."
                        )
                        
                        PrivacySection(
                            title: "Third-Party Services",
                            content: "We use Firebase for authentication and data storage, and Google services for maps. These services have their own privacy policies and security measures."
                        )
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Privacy Policy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct PrivacySection: View {
    let title: String
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text(content)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(nil)
        }
    }
}
