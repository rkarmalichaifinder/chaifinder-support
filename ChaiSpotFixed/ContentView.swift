import SwiftUI

struct ContentView: View {
    @EnvironmentObject var sessionStore: SessionStore

    var body: some View {
        Group {
            if sessionStore.currentUser != nil {
                MainAppView()
            } else {
                SignInView()
            }
        }
    }
}
