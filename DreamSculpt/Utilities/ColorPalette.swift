//
//  ColorPalette.swift
//  DreamSculpt
//

import SwiftUI

enum ColorPalette {
    static let primary = Color(hex: "6366F1")
    static let primaryDark = Color(hex: "4F46E5")
    static let accent = Color(hex: "8B5CF6")
    static let background = Color(hex: "0F0F23")
    static let surface = Color(hex: "1A1A2E")
    static let surfaceLight = Color(hex: "2A2A4A")
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.7)
    static let textMuted = Color.white.opacity(0.4)
    static let glassBorder = Color.white.opacity(0.15)
    static let glassBackground = Color.white.opacity(0.08)
    static let success = Color(hex: "10B981")
    static let warning = Color(hex: "F59E0B")
    static let error = Color(hex: "EF4444")

    static let gradientPrimary = LinearGradient(
        colors: [primary, accent],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let gradientBackground = LinearGradient(
        colors: [background, surface],
        startPoint: .top,
        endPoint: .bottom
    )
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
