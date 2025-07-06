import SwiftUI

struct SplashScreenView: View {
    var body: some View {
        ZStack {
            Color.white.edgesIgnoringSafeArea(.all)
            Image("AppLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 160, height: 160)
        }
    }
}
