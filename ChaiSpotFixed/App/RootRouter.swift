import SwiftUI

struct RootRouter: View {
    @EnvironmentObject var session: SessionStore
    @State private var didCompleteTasteSetup = false
    @State private var isLoadingProfile = false
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var showingSplash = true

    var body: some View {
        Group {
            if showingSplash {
                SplashScreenView()
                    .onAppear {
                        // Optimized splash duration - show for 1.5 seconds or until auth is ready
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            withAnimation(.easeInOut(duration: 0.5)) {
                                showingSplash = false
                            }
                        }
                        
                        // Also dismiss splash early if auth is already resolved
                        if !session.isLoading {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                                withAnimation(.easeInOut(duration: 0.5)) {
                                    showingSplash = false
                                }
                            }
                        }
                    }
            } else if session.isLoading || isLoadingProfile {
                loadingView
            } else if !session.isAuthenticated {
                OnboardingExplainerView()
            } else if !didCompleteTasteSetup {
                TasteOnboardingView(onDone: { 
                    withAnimation(.easeInOut(duration: 0.5)) {
                        didCompleteTasteSetup = true
                    }
                })
            } else {
                MainAppView()
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .onAppear {
            loadUserProfileIfNeeded()
        }
        .alert("Profile Error", isPresented: $showingError) {
            Button("Try Again") {
                loadUserProfileIfNeeded()
            }
            Button("Continue") {
                // Continue without profile
            }
        } message: {
            Text(errorMessage ?? "Unable to load user profile")
        }
    }
    
    private var loadingView: some View {
        ZStack {
            DesignSystem.Colors.background
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // App logo
                Image("AppLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
                    .cornerRadius(16)
                
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                        .progressViewStyle(CircularProgressViewStyle(tint: DesignSystem.Colors.primary))
                    
                    Text("Loading...")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("Setting up your personalized experience")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
    }
    
    private func loadUserProfileIfNeeded() {
        guard session.isAuthenticated && !isLoadingProfile else { return }
        
        isLoadingProfile = true
        errorMessage = nil
        
        session.loadUserProfile(uid: session.currentUser?.uid ?? "") { profile in
            DispatchQueue.main.async {
                isLoadingProfile = false
                
                if let profile = profile {
                    didCompleteTasteSetup = profile.hasTasteSetup
                } else {
                    // Profile loading failed
                    errorMessage = "Failed to load user profile"
                    showingError = true
                }
            }
        }
    }
}

// MARK: - Preview
struct RootRouter_Previews: PreviewProvider {
    static var previews: some View {
        RootRouter()
            .environmentObject(SessionStore())
    }
}
