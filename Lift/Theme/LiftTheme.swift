import SwiftUI

/// Color tokens for the Lift visual language. Built around a deep navy canvas
/// with a single warm purple accent. Stays cohesive in both light and dark
/// system appearances; the app currently overrides to dark via LiftApp.
enum LiftTheme {
    // Brand
    static let accent = Color(red: 0.58, green: 0.45, blue: 0.96)
    static let accentMuted = Color(red: 0.58, green: 0.45, blue: 0.96).opacity(0.18)
    static let accentBorder = Color(red: 0.58, green: 0.45, blue: 0.96).opacity(0.45)

    // Surfaces (dark canvas)
    static let canvas = Color(red: 0.04, green: 0.04, blue: 0.09)
    static let card = Color(red: 0.08, green: 0.08, blue: 0.16)
    static let cardBorder = Color.white.opacity(0.06)
    static let raisedFill = Color.white.opacity(0.04)

    // Semantic
    static let success = Color(red: 0.30, green: 0.78, blue: 0.45)
    static let warning = Color(red: 0.95, green: 0.62, blue: 0.25)
    static let danger = Color(red: 0.92, green: 0.36, blue: 0.36)

    // Text
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.62)
    static let textTertiary = Color.white.opacity(0.38)
}

extension View {
    /// Applies the Lift dark canvas + tint to this subtree.
    func liftThemedScene() -> some View {
        self
            .preferredColorScheme(.dark)
            .tint(LiftTheme.accent)
            .background(LiftTheme.canvas.ignoresSafeArea())
    }
}
