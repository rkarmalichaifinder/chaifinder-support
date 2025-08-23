import SwiftUI

struct MainAppView: View {
    @EnvironmentObject var sessionStore: SessionStore
    @State private var selectedTab: Int = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            FeedView()
                .tabItem {
                    Label("Feed", systemImage: "list.bullet")
                }
                .tag(0)
            
            PersonalizedMapView()
                .tabItem {
                    Label("My Chai Map", systemImage: "map")
                }
                .tag(1)
            
            FriendsView()
                .tabItem {
                    Label("Social", systemImage: "person.3")
                }
                .tag(2)
                
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.crop.circle")
                }
                .tag(3)
        }
        .accentColor(DesignSystem.Colors.primary)
        .environmentObject(sessionStore)
    }
}

struct MainAppView_Previews: PreviewProvider {
    static var previews: some View {
        MainAppView()
            .environmentObject(SessionStore())
    }
}
