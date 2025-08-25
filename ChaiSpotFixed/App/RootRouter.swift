import SwiftUI

struct RootRouter: View {
    @EnvironmentObject var session: SessionStore
    @State private var isLoadingProfile = false
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var showingSplash = true
    
    // Compute taste setup completion from the actual user profile
    private var didCompleteTasteSetup: Bool {
        let result = session.userProfile?.hasTasteSetup ?? false
        print("🔍 Taste setup check: userProfile=\(session.userProfile?.hasTasteSetup ?? false), result=\(result)")
        return result
    }

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
                    // Force a profile reload to update the UI
                    if let uid = session.currentUser?.uid {
                        session.loadUserProfile(uid: uid) { _ in
                            // Profile reloaded, UI should update automatically
                        }
                    }
                })
            } else {
                MainAppView()
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .onAppear {
            loadUserProfileIfNeeded()
            setupNotificationListeners()
        }
        .onChange(of: session.userProfile) { newProfile in
            // Force view refresh when user profile changes
            // This ensures the taste onboarding logic re-evaluates
            print("🔄 User profile changed: hasTasteSetup=\(newProfile?.hasTasteSetup ?? false)")
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
        
        print("🔄 Loading user profile for: \(session.currentUser?.uid ?? "nil")")
        isLoadingProfile = true
        errorMessage = nil
        
        session.loadUserProfile(uid: session.currentUser?.uid ?? "") { profile in
            DispatchQueue.main.async {
                isLoadingProfile = false
                
                if let profile = profile {
                    print("✅ Profile loaded successfully: hasTasteSetup=\(profile.hasTasteSetup)")
                } else {
                    // Profile loading failed
                    errorMessage = "Failed to load user profile"
                    showingError = true
                    print("❌ Profile loading failed")
                }
            }
        }
    }
    
    private func setupNotificationListeners() {
        print("🔔 Setting up notification listeners")
        // Listen for taste setup completion
        NotificationCenter.default.addObserver(
            forName: .tasteSetupCompleted,
            object: nil,
            queue: .main
        ) { _ in
            print("🔔 Taste setup completed notification received")
            // Force a profile reload to update the UI state
            if let uid = session.currentUser?.uid {
                print("🔄 Reloading profile after taste setup completion")
                session.loadUserProfile(uid: uid) { profile in
                    // Profile reloaded, UI should update automatically
                    if let profile = profile {
                        print("✅ Profile reloaded after taste setup: hasTasteSetup=\(profile.hasTasteSetup)")
                    } else {
                        print("❌ Profile reload failed after taste setup")
                    }
                }
            } else {
                print("❌ No current user found for profile reload")
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
