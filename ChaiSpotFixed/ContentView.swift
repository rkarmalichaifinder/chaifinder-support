import SwiftUI
import MapKit
import Firebase
import FirebaseFirestore
import FirebaseFirestoreSwift
import CoreLocation

struct ContentView: View {
    @State private var selectedTab: Int = 0
    @StateObject private var notificationChecker = NotificationChecker()

    var body: some View {
        TabView(selection: $selectedTab) {
            FeedView()
                .tabItem {
                    Label("Feed", systemImage: "bubble.left.and.bubble.right")
                }
                .tag(0)

            SearchView()
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
                .tag(1)

            FriendsView()
                .tabItem {
                    Label("Friends", systemImage: "person.2")
                }
                .tag(2)
                
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.crop.circle")
                }
                .tag(3)
        }
        .onAppear {
            if let uid = Auth.auth().currentUser?.uid {
                print("Logged in as \(uid)")
                FriendService.createUserDocumentIfNeeded { success in
                    if success {
                        notificationChecker.checkForNewActivity()
                    } else {
                        print("❌ Failed to ensure Firestore user document.")
                    }
                }
            }
        }
    }
}
