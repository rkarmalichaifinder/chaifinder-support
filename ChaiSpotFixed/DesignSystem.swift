import SwiftUI

// MARK: - Design System
struct DesignSystem {
    
    // MARK: - Colors
    struct Colors {
            static let primary = Color(hex: "#FF6B35")
    static let secondary = Color(hex: "#F7931E")
    static let accent = Color(hex: "#4ECDC4")
    static let textPrimary = Color(hex: "#1A1A1A")
        static let textSecondary = Color(hex: "#666666")
        static let background = Color(hex: "#F8F9FA")
        static let cardBackground = Color.white
        static let border = Color(hex: "#E1E5E9")
        static let searchBackground = Color(hex: "#F1F3F4")
        static let tabSelected = Color(hex: "#FF6B35")
        static let tabUnselected = Color(hex: "#999999")
        static let ratingGreen = Color(hex: "#4CAF50")
        
        // New rating colors
        static let creaminessRating = Color(hex: "#F4E4BC") // Cream color
        static let chaiStrengthRating = Color(hex: "#8B4513") // Brown color
        static let flavorNotesRating = Color(hex: "#9370DB") // Purple color
        
        // Enhanced accessibility colors
        static let success = Color(hex: "#28A745")
        static let warning = Color(hex: "#FFC107")
        static let error = Color(hex: "#DC3545")
        static let info = Color(hex: "#17A2B8")
        
        // High contrast support
        static let highContrastBackground = Color(hex: "#FFFFFF")
        static let highContrastText = Color(hex: "#000000")
        static let highContrastAccent = Color(hex: "#007AFF")
    }
    
    // MARK: - Typography
    struct Typography {
        static let titleLarge = Font.system(size: UIDevice.current.userInterfaceIdiom == .pad ? 32 : 28, weight: .bold, design: .default)
        static let titleMedium = Font.system(size: UIDevice.current.userInterfaceIdiom == .pad ? 28 : 24, weight: .bold, design: .default)
        static let headline = Font.system(size: UIDevice.current.userInterfaceIdiom == .pad ? 24 : 20, weight: .semibold, design: .default)
        static let bodyLarge = Font.system(size: UIDevice.current.userInterfaceIdiom == .pad ? 20 : 18, weight: .regular, design: .default)
        static let bodyMedium = Font.system(size: UIDevice.current.userInterfaceIdiom == .pad ? 18 : 16, weight: .regular, design: .default)
        static let bodySmall = Font.system(size: UIDevice.current.userInterfaceIdiom == .pad ? 16 : 14, weight: .regular, design: .default)
        static let caption = Font.system(size: UIDevice.current.userInterfaceIdiom == .pad ? 14 : 12, weight: .medium, design: .default)
        static let caption2 = Font.system(size: UIDevice.current.userInterfaceIdiom == .pad ? 12 : 10, weight: .medium, design: .default)
        
        // Accessibility-focused typography
        static let accessibleTitle = Font.system(size: UIDevice.current.userInterfaceIdiom == .pad ? 34 : 30, weight: .bold, design: .default)
        static let accessibleBody = Font.system(size: UIDevice.current.userInterfaceIdiom == .pad ? 22 : 18, weight: .regular, design: .default)
    }
    
    // MARK: - Spacing (iPad-optimized)
    struct Spacing {
        static let xs: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 8 : 4
        static let sm: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 16 : 8
        static let md: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 24 : 16
        static let lg: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 32 : 24
        static let xl: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 48 : 32
        static let xxl: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 64 : 48
        
        // Accessibility spacing
        static let accessibleTouch: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 44 : 44
    }
    
    // MARK: - Corner Radius
    struct CornerRadius {
        static let small: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 12 : 8
        static let medium: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 16 : 12
        static let large: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 20 : 16
        static let extraLarge: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 24 : 20
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
    
    // MARK: - View Modifiers
    struct ViewModifiers {
        /// Enables keyboard dismissal by swiping down or tapping outside text fields
        struct KeyboardDismissible: ViewModifier {
            func body(content: Content) -> some View {
                content
                    .onTapGesture {
                        // Dismiss keyboard by resigning first responder
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                    .gesture(
                        DragGesture()
                            .onEnded { value in
                                // Dismiss keyboard on downward swipe
                                if value.translation.height > 50 {
                                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                }
                            }
                    )
            }
        }
        
        /// Alternative keyboard dismissible modifier for views with multiple text fields
        struct MultiFieldKeyboardDismissible: ViewModifier {
            func body(content: Content) -> some View {
                content
                    .onTapGesture {
                        // Dismiss keyboard by resigning first responder
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                    .gesture(
                        DragGesture()
                            .onEnded { value in
                                // Dismiss keyboard on downward swipe
                                if value.translation.height > 50 {
                                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                }
                            }
                    )
            }
        }
        
        /// Specialized keyboard dismissible modifier for search bars
        struct SearchBarKeyboardDismissible: ViewModifier {
            func body(content: Content) -> some View {
                content
                    .gesture(
                        DragGesture()
                            .onEnded { value in
                                // Only dismiss keyboard on significant downward swipe
                                if value.translation.height > 100 {
                                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                }
                            }
                    )
            }
        }
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
        
        // Accessibility layout
        static let minTouchTarget: CGFloat = 44
        static let maxContentWidthAccessible: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 700 : .infinity
    }
    
    // MARK: - Animation
    struct Animation {
        static let quick = SwiftUI.Animation.easeInOut(duration: 0.2)
        static let standard = SwiftUI.Animation.easeInOut(duration: 0.3)
        static let slow = SwiftUI.Animation.easeInOut(duration: 0.5)
        static let spring = SwiftUI.Animation.spring(response: 0.5, dampingFraction: 0.8, blendDuration: 0)
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
            .frame(minHeight: DesignSystem.Layout.minTouchTarget)
            .background(DesignSystem.Colors.primary)
            .cornerRadius(DesignSystem.CornerRadius.medium)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(DesignSystem.Animation.quick, value: configuration.isPressed)
            .lineLimit(2)
            .minimumScaleFactor(0.9)
            .accessibilityLabel("Primary action button")
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
            .frame(minHeight: DesignSystem.Layout.minTouchTarget)
            .background(DesignSystem.Colors.primary.opacity(0.1))
            .cornerRadius(DesignSystem.CornerRadius.medium)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(DesignSystem.Animation.quick, value: configuration.isPressed)
            .lineLimit(2)
            .minimumScaleFactor(0.9)
            .accessibilityLabel("Secondary action button")
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

// MARK: - Enhanced Button Styles
struct SuccessButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignSystem.Typography.bodyMedium)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .frame(minHeight: DesignSystem.Layout.minTouchTarget)
            .background(DesignSystem.Colors.success)
            .cornerRadius(DesignSystem.CornerRadius.medium)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(DesignSystem.Animation.quick, value: configuration.isPressed)
    }
}

struct WarningButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignSystem.Typography.bodyMedium)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .frame(minHeight: DesignSystem.Layout.minTouchTarget)
            .background(DesignSystem.Colors.warning)
            .cornerRadius(DesignSystem.CornerRadius.medium)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(DesignSystem.Animation.quick, value: configuration.isPressed)
    }
}

// MARK: - Loading States
struct LoadingView: View {
    let message: String
    let showSpinner: Bool
    
    init(_ message: String = "Loading...", showSpinner: Bool = true) {
        self.message = message
        self.showSpinner = showSpinner
    }
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            if showSpinner {
                ProgressView()
                    .scaleEffect(1.2)
                    .accessibilityLabel("Loading indicator")
            }
            Text(message)
                .font(DesignSystem.Typography.bodyMedium)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(DesignSystem.Spacing.lg)
        .background(.ultraThinMaterial)
        .cornerRadius(DesignSystem.CornerRadius.large)
    }
}

// MARK: - Empty State
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?
    
    init(icon: String, title: String, message: String, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .accessibilityHidden(true)
            
            VStack(spacing: DesignSystem.Spacing.sm) {
                Text(title)
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                
                Text(message)
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(DesignSystem.Typography.bodyMedium)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                        .padding(.vertical, DesignSystem.Spacing.md)
                        .background(DesignSystem.Colors.primary)
                        .cornerRadius(DesignSystem.CornerRadius.medium)
                }
                .accessibilityLabel("Action button: \(actionTitle)")
            }
        }
        .padding(DesignSystem.Spacing.xl)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - View Extensions
extension View {
    /// Applies keyboard dismissible behavior to the view
    func keyboardDismissible() -> some View {
        self.modifier(DesignSystem.ViewModifiers.KeyboardDismissible())
    }
    
    /// Applies keyboard dismissible behavior for views with multiple text fields
    func multiFieldKeyboardDismissible() -> some View {
        self.modifier(DesignSystem.ViewModifiers.MultiFieldKeyboardDismissible())
    }
    
    /// Applies specialized keyboard dismissible behavior for search bars
    func searchBarKeyboardDismissible() -> some View {
        self.modifier(DesignSystem.ViewModifiers.SearchBarKeyboardDismissible())
    }
    
    /// iPad-optimized spacing and sizing
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
    
    // Accessibility helpers
    func accessibleButton() -> some View {
        self
            .frame(minHeight: DesignSystem.Layout.minTouchTarget)
            .contentShape(Rectangle())
    }
    
    func accessibleText() -> some View {
        self
            .font(DesignSystem.Typography.accessibleBody)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
    }
} 