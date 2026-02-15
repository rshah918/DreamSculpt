//
//  LoadingIndicator.swift
//  DreamSculpt
//

import SwiftUI

struct LoadingIndicator: View {
    @State private var rotation: Double = 0
    @State private var scale: CGFloat = 1.0

    var size: CGFloat = 24
    var lineWidth: CGFloat = 3

    var body: some View {
        ZStack {
            Circle()
                .stroke(ColorPalette.glassBorder, lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: 0.7)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [ColorPalette.primary, ColorPalette.accent, ColorPalette.primary.opacity(0)]),
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(rotation))
        }
        .frame(width: size, height: size)
        .scaleEffect(scale)
        .onAppear {
            withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                rotation = 360
            }
            withAnimation(.easeInOut(duration: 0.8).repeatForever()) {
                scale = 1.1
            }
        }
    }
}

struct PulsingDot: View {
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0.5

    var color: Color = ColorPalette.primary
    var size: CGFloat = 12

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.6).repeatForever()) {
                    scale = 1.2
                    opacity = 1.0
                }
            }
    }
}
