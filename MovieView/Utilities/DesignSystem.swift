import SwiftUI

/// Design system for the MovieView app
enum DesignSystem {
    /// Spacing values used throughout the app
    enum Spacing {
        static let xxsmall: CGFloat = 4
        static let xsmall: CGFloat = 8
        static let small: CGFloat = 12
        static let medium: CGFloat = 16
        static let large: CGFloat = 24
        static let xlarge: CGFloat = 32
        static let xxlarge: CGFloat = 48
    }
    
    /// Corner radius values
    enum CornerRadius {
        static let small: CGFloat = 4
        static let medium: CGFloat = 8
        static let large: CGFloat = 12
        static let xlarge: CGFloat = 16
    }
    
    /// Animation durations
    enum Animation {
        static let quick: CGFloat = 0.2
        static let medium: CGFloat = 0.3
        static let slow: CGFloat = 0.5
    }
    
    /// Shadow values
    enum Shadow {
        static let small = Color.black.opacity(0.1)
        static let medium = Color.black.opacity(0.15)
        static let large = Color.black.opacity(0.2)
    }
}

// MARK: - View Modifiers
extension View {
    /// Applies a card style to a view
    func cardStyle() -> some View {
        self
            .padding(DesignSystem.Spacing.medium)
            .background(.background.secondary)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
            .shadow(color: DesignSystem.Shadow.small, radius: 4, x: 0, y: 2)
    }
    
    /// Applies a hover effect to a view
    func hoverEffect(scale: CGFloat = 1.02) -> some View {
        self.modifier(HoverEffectModifier(scale: scale))
    }
}

// MARK: - Custom Modifiers
struct HoverEffectModifier: ViewModifier {
    let scale: CGFloat
    @State private var isHovered = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isHovered ? scale : 1.0)
            .animation(.spring(response: DesignSystem.Animation.quick), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
} 