//
//  GlassmorphicModifier.swift
//  DreamSculpt
//

import SwiftUI

struct GlassmorphicModifier: ViewModifier {
    var cornerRadius: CGFloat = 16
    var borderOpacity: CGFloat = 0.15
    var backgroundOpacity: CGFloat = 0.1

    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .background(Color.white.opacity(backgroundOpacity))
            .cornerRadius(cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.white.opacity(borderOpacity), lineWidth: 0.5)
            )
    }
}

extension View {
    func glassmorphic(
        cornerRadius: CGFloat = 16,
        borderOpacity: CGFloat = 0.15,
        backgroundOpacity: CGFloat = 0.1
    ) -> some View {
        modifier(GlassmorphicModifier(
            cornerRadius: cornerRadius,
            borderOpacity: borderOpacity,
            backgroundOpacity: backgroundOpacity
        ))
    }
}

struct GlassmorphicCard<Content: View>: View {
    let content: Content
    var cornerRadius: CGFloat = 16
    var padding: CGFloat = 16

    init(cornerRadius: CGFloat = 16, padding: CGFloat = 16, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.cornerRadius = cornerRadius
        self.padding = padding
    }

    var body: some View {
        content
            .padding(padding)
            .glassmorphic(cornerRadius: cornerRadius)
    }
}
