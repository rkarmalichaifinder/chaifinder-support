import SwiftUI

struct SplashScreenView: View {
    var body: some View {
        ZStack {
            Color.white.edgesIgnoringSafeArea(.all)
            Image(systemName: "cup.and.saucer.fill")
                .font(.system(size: 80))
                .foregroundColor(DesignSystem.Colors.primary)
                .frame(width: 160, height: 160)
        }
    }
}
