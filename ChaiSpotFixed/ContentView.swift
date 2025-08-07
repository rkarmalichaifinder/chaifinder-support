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
            } else {
                Group {
                    if sessionStore.currentUser != nil {
                        MainAppView()
                    } else {
                        SignInView()
                    }
                }
                .transition(.opacity)
            }
        }
    }
}
