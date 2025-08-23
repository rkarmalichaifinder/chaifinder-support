import SwiftUI

struct SplashScreenView: View {
    @State private var logoScale: CGFloat = 0.8
    @State private var logoOpacity: Double = 0
    @State private var titleOpacity: Double = 0
    @State private var subtitleOpacity: Double = 0
    @State private var backgroundGradient = false
    
    var body: some View {
        ZStack {
            // Animated background
            LinearGradient(
                colors: [
                    Color.orange,
                    Color.orange.opacity(0.8),
                    Color.orange.opacity(0.6)
                ],
                startPoint: backgroundGradient ? .topLeading : .bottomTrailing,
                endPoint: backgroundGradient ? .bottomTrailing : .topLeading
            )
            .edgesIgnoringSafeArea(.all)
            .onAppear {
                withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                    backgroundGradient.toggle()
                }
            }
            
            VStack(spacing: 24) {
                // Animated logo
                Image("AppLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 120, height: 120)
                    .cornerRadius(20)
                    .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)
                    .onAppear {
                        withAnimation(.spring(response: 0.8, dampingFraction: 0.6, blendDuration: 0)) {
                            logoScale = 1.0
                            logoOpacity = 1.0
                        }
                    }
                
                // Animated title
                Text("Chai Finder")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                    .opacity(titleOpacity)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 0.8).delay(0.3)) {
                            titleOpacity = 1.0
                        }
                    }
                
                // Animated subtitle
                Text("Track and share the best Desi chai with your friends")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                    .opacity(subtitleOpacity)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 0.8).delay(0.6)) {
                            subtitleOpacity = 1.0
                        }
                    }
                
                // Loading indicator
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(0.8)
                    .opacity(subtitleOpacity)
            }
            .padding(.horizontal, 40)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Chai Finder app loading screen")
        .accessibilityHint("Track and share the best Desi chai with your friends")
    }
}

struct SplashScreenView_Previews: PreviewProvider {
    static var previews: some View {
        SplashScreenView()
    }
}
