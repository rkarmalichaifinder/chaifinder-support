import SwiftUI

struct AuthGate<Content: View>: View {
    @EnvironmentObject var session: SessionStore
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        Group {
            if session.currentUser != nil {
                content
            } else {
                OnboardingExplainerView()
            }
        }
    }
}
