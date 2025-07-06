import SwiftUI
import FirebaseAuth

struct MainAppView: View {
    @State private var isLoggedIn: Bool = Auth.auth().currentUser != nil

    var body: some View {
        Group {
            if isLoggedIn {
                ContentView()
            } else {
                SignInView()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .authStateChanged)) { _ in
            isLoggedIn = Auth.auth().currentUser != nil
        }
        .onAppear {
            NotificationCenter.default.addObserver(
                forName: .authStateChanged,
                object: nil,
                queue: .main
            ) { _ in
                isLoggedIn = Auth.auth().currentUser != nil
            }
        }
    }
}
