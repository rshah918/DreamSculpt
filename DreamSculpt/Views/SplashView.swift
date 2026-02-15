//
//  SplashView.swift
//  DreamSculpt
//

import SwiftUI

struct SplashView: View {
    @State private var logoScale: CGFloat = 0.5
    @State private var logoOpacity: Double = 0
    @State private var titleOffset: CGFloat = 30
    @State private var titleOpacity: Double = 0
    @State private var subtitleOpacity: Double = 0
    @State private var ringRotation: Double = 0
    @State private var ringScale: CGFloat = 0.8
    @State private var showParticles: Bool = false

    let onComplete: () -> Void

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(hex: "0A0A1A"),
                    Color(hex: "1A1A3A"),
                    Color(hex: "0F0F25")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Animated particles
            if showParticles {
                ParticlesView()
            }

            VStack(spacing: 24) {
                Spacer()

                // Logo with animated ring
                ZStack {
                    // Outer glow ring
                    Circle()
                        .stroke(
                            AngularGradient(
                                colors: [ColorPalette.primary, ColorPalette.accent, ColorPalette.primary],
                                center: .center
                            ),
                            lineWidth: 3
                        )
                        .frame(width: 140, height: 140)
                        .rotationEffect(.degrees(ringRotation))
                        .scaleEffect(ringScale)
                        .opacity(logoOpacity * 0.6)
                        .blur(radius: 2)

                    // Inner circle background
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [ColorPalette.surface, ColorPalette.background],
                                center: .center,
                                startRadius: 0,
                                endRadius: 60
                            )
                        )
                        .frame(width: 120, height: 120)
                        .overlay(
                            Circle()
                                .stroke(ColorPalette.glassBorder, lineWidth: 1)
                        )

                    // Logo icon
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 48, weight: .light))
                        .foregroundStyle(ColorPalette.gradientPrimary)
                }
                .scaleEffect(logoScale)
                .opacity(logoOpacity)

                // App title
                VStack(spacing: 8) {
                    Text("DreamSculpt")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, Color.white.opacity(0.8)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .offset(y: titleOffset)
                        .opacity(titleOpacity)

                    Text("Sketch your imagination")
                        .font(.subheadline)
                        .foregroundColor(ColorPalette.textMuted)
                        .opacity(subtitleOpacity)
                }

                Spacer()
                Spacer()
            }
        }
        .onAppear {
            startAnimation()
        }
    }

    private func startAnimation() {
        // Logo fade in and scale
        withAnimation(.spring(response: 0.8, dampingFraction: 0.6)) {
            logoScale = 1.0
            logoOpacity = 1.0
        }

        // Ring animation
        withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
            ringScale = 1.0
        }

        // Continuous ring rotation
        withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
            ringRotation = 360
        }

        // Particles
        withAnimation(.easeIn(duration: 0.3).delay(0.2)) {
            showParticles = true
        }

        // Title animation
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3)) {
            titleOffset = 0
            titleOpacity = 1
        }

        // Subtitle fade in
        withAnimation(.easeIn(duration: 0.4).delay(0.5)) {
            subtitleOpacity = 1
        }

        // Complete after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            onComplete()
        }
    }
}

struct ParticlesView: View {
    @State private var particles: [Particle] = []

    var body: some View {
        GeometryReader { geo in
            ForEach(particles) { particle in
                Circle()
                    .fill(particle.color)
                    .frame(width: particle.size, height: particle.size)
                    .position(particle.position)
                    .opacity(particle.opacity)
                    .blur(radius: particle.size / 4)
            }
            .onAppear {
                generateParticles(in: geo.size)
            }
        }
    }

    private func generateParticles(in size: CGSize) {
        for _ in 0..<20 {
            let particle = Particle(
                position: CGPoint(
                    x: CGFloat.random(in: 0...size.width),
                    y: CGFloat.random(in: 0...size.height)
                ),
                size: CGFloat.random(in: 2...6),
                color: [ColorPalette.primary, ColorPalette.accent, Color.white].randomElement()!.opacity(0.3),
                opacity: Double.random(in: 0.1...0.4)
            )
            particles.append(particle)
        }

        // Animate particles
        for i in particles.indices {
            let delay = Double.random(in: 0...1)
            withAnimation(.easeInOut(duration: Double.random(in: 2...4)).repeatForever(autoreverses: true).delay(delay)) {
                particles[i].opacity = Double.random(in: 0.1...0.5)
            }
        }
    }
}

struct Particle: Identifiable {
    let id = UUID()
    var position: CGPoint
    var size: CGFloat
    var color: Color
    var opacity: Double
}

#Preview {
    SplashView(onComplete: {})
}
