import SwiftUI

struct ContentView: View {
    @StateObject private var sessionStore = SessionStore()
    @StateObject private var notificationChecker = NotificationChecker()
    
    var body: some View {
        Group {
            if sessionStore.isAuthenticated {
                MainAppView()
                    .environmentObject(sessionStore)
            } else {
                SignInView()
                    .environmentObject(sessionStore)
            }
        }
        .onAppear {
            // Check for saved user data
            if let savedUserData = UserDefaults.standard.data(forKey: "currentUser"),
               let savedUser = try? JSONDecoder().decode(UserProfile.self, from: savedUserData) {
                sessionStore.user = savedUser
                sessionStore.isAuthenticated = true
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
