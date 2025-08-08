import SwiftUI

struct ContentView: View {
    @EnvironmentObject var sessionStore: SessionStore
    @State private var showingSplash = true

    var body: some View {
        ZStack {
            if showingSplash {
                SplashScreenView()
                    .onAppear {
                        // Show splash screen for 2 seconds
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            withAnimation(.easeInOut(duration: 0.5)) {
                                showingSplash = false
                            }
                        }
                    }
                    .transition(.opacity)
            } else {
                Group {
                    if sessionStore.isLoading {
                        // Show loading state while Firebase is initializing
                        VStack(spacing: DesignSystem.Spacing.lg) {
                            ProgressView()
                                .scaleEffect(1.2)
                            Text("Loading...")
                                .font(DesignSystem.Typography.bodyLarge)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if sessionStore.currentUser != nil {
                        MainAppView()
                    } else {
                        SignInView()
                    }
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.5), value: showingSplash)
    }
}
