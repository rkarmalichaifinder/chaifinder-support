import SwiftUI

// MARK: - Design System
struct DesignSystem {
    
    // MARK: - Colors
    struct Colors {
        static let primary = Color(hex: "#FF6B35")
        static let secondary = Color(hex: "#F7931E")
        static let textPrimary = Color(hex: "#1A1A1A")
        static let textSecondary = Color(hex: "#666666")
        static let background = Color(hex: "#F8F9FA")
        static let cardBackground = Color.white
        static let border = Color(hex: "#E1E5E9")
        static let searchBackground = Color(hex: "#F1F3F4")
        static let tabSelected = Color(hex: "#FF6B35")
        static let tabUnselected = Color(hex: "#999999")
        static let ratingGreen = Color(hex: "#4CAF50")
    }
    
    // MARK: - Typography
    struct Typography {
        static let titleLarge = Font.system(size: UIDevice.current.userInterfaceIdiom == .pad ? 32 : 28, weight: .bold)
        static let titleMedium = Font.system(size: UIDevice.current.userInterfaceIdiom == .pad ? 28 : 24, weight: .bold)
        static let headline = Font.system(size: UIDevice.current.userInterfaceIdiom == .pad ? 24 : 20, weight: .semibold)
        static let bodyLarge = Font.system(size: UIDevice.current.userInterfaceIdiom == .pad ? 20 : 18, weight: .regular)
        static let bodyMedium = Font.system(size: UIDevice.current.userInterfaceIdiom == .pad ? 18 : 16, weight: .regular)
        static let bodySmall = Font.system(size: UIDevice.current.userInterfaceIdiom == .pad ? 16 : 14, weight: .regular)
        static let caption = Font.system(size: UIDevice.current.userInterfaceIdiom == .pad ? 14 : 12, weight: .medium)
    }
    
    // MARK: - Spacing (iPad-optimized)
    struct Spacing {
        static let xs: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 8 : 4
        static let sm: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 16 : 8
        static let md: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 24 : 16
        static let lg: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 32 : 24
        static let xl: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 48 : 32
        static let xxl: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 64 : 48
    }
    
    // MARK: - Corner Radius
    struct CornerRadius {
        static let small: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 12 : 8
        static let medium: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 16 : 12
        static let large: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 20 : 16
    }
    
    // MARK: - Shadows
    struct Shadows {
        struct Shadow {
            let color: Color
            let radius: CGFloat
            let x: CGFloat
            let y: CGFloat
        }
        
        static let small = Shadow(
            color: Color.black.opacity(0.1),
            radius: UIDevice.current.userInterfaceIdiom == .pad ? 4 : 2,
            x: 0,
            y: UIDevice.current.userInterfaceIdiom == .pad ? 2 : 1
        )
        
        static let medium = Shadow(
            color: Color.black.opacity(0.15),
            radius: UIDevice.current.userInterfaceIdiom == .pad ? 8 : 4,
            x: 0,
            y: UIDevice.current.userInterfaceIdiom == .pad ? 4 : 2
        )
        
        static let large = Shadow(
            color: Color.black.opacity(0.2),
            radius: UIDevice.current.userInterfaceIdiom == .pad ? 12 : 8,
            x: 0,
            y: UIDevice.current.userInterfaceIdiom == .pad ? 6 : 4
        )
    }
    
    // MARK: - Layout
    struct Layout {
        // Maximum content width for iPad to prevent content from stretching too wide
        static let maxContentWidth: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 600 : .infinity
        
        // Side padding for iPad to center content
        static let sidePadding: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 40 : 16
        
        // Card spacing for iPad
        static let cardSpacing: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 24 : 16
        
        // Grid columns for iPad
        static let gridColumns: Int = UIDevice.current.userInterfaceIdiom == .pad ? 2 : 1
    }
}

// MARK: - Shadow Structure
struct Shadow {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - View Modifiers
struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(DesignSystem.Spacing.lg)
            .background(DesignSystem.Colors.cardBackground)
            .cornerRadius(DesignSystem.CornerRadius.medium)
            .shadow(
                color: DesignSystem.Shadows.small.color,
                radius: DesignSystem.Shadows.small.radius,
                x: DesignSystem.Shadows.small.x,
                y: DesignSystem.Shadows.small.y
            )
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignSystem.Typography.bodyMedium)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background(DesignSystem.Colors.primary)
            .cornerRadius(DesignSystem.CornerRadius.medium)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
            .lineLimit(2)
            .minimumScaleFactor(0.9)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignSystem.Typography.bodyMedium)
            .fontWeight(.semibold)
            .foregroundColor(DesignSystem.Colors.primary)
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background(DesignSystem.Colors.primary.opacity(0.1))
            .cornerRadius(DesignSystem.CornerRadius.medium)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
            .lineLimit(2)
            .minimumScaleFactor(0.9)
    }
}

struct SearchBarStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(DesignSystem.Spacing.md)
            .background(DesignSystem.Colors.searchBackground)
            .cornerRadius(DesignSystem.CornerRadius.large)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                    .stroke(DesignSystem.Colors.border, lineWidth: 1)
            )
    }
} 

// MARK: - iPad-specific extensions
extension View {
    func iPadOptimized() -> some View {
        self
            .frame(maxWidth: DesignSystem.Layout.maxContentWidth)
            .padding(.horizontal, DesignSystem.Layout.sidePadding)
    }
    
    func iPadCardStyle() -> some View {
        self
            .padding(DesignSystem.Spacing.lg)
            .background(DesignSystem.Colors.cardBackground)
            .cornerRadius(DesignSystem.CornerRadius.large)
            .shadow(
                color: DesignSystem.Shadows.medium.color,
                radius: DesignSystem.Shadows.medium.radius,
                x: DesignSystem.Shadows.medium.x,
                y: DesignSystem.Shadows.medium.y
            )
    }
} 