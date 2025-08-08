import SwiftUI

struct ContentView: View {
    @EnvironmentObject var sessionStore: SessionStore
    @State private var showingSplash = true

    var body: some View {
        ZStack {
            // Main body always present under the splash so we never render "nothing"
            Group {
                if sessionStore.isLoading {
                    VStack(spacing: DesignSystem.Spacing.lg) {
                        ProgressView().scaleEffect(1.2)
                        Text("Loading...")
                            .font(DesignSystem.Typography.bodyLarge)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if sessionStore.currentUser != nil {
                    MainAppView()
                        .onAppear { print("✅ Showing MainAppView") }
                } else {
                    SignInView()
                        .onAppear { print("✅ Showing SignInView") }
                }
            }

            // Splash overlays for a fixed time, then fades out
            if showingSplash {
                SplashScreenView()
                    .onAppear {
                        print("🟣 Splash appeared")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            withAnimation(.easeInOut(duration: 0.4)) {
                                showingSplash = false
                            }
                            print("🟣 Splash dismissed")
                        }
                    }
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: showingSplash)
    }
}
