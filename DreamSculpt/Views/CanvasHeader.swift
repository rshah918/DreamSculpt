//
//  CanvasHeader.swift
//  DreamSculpt
//
//  Aurora Header - Premium header with dynamic aurora effects and branding

import SwiftUI

// MARK: - Aurora Header
struct AuroraHeader: View {
    @EnvironmentObject var appState: AppState
    @State private var sparkleRotation: Double = 0
    @State private var shimmerOffset: CGFloat = -200
    @State private var glowPulse: Bool = false

    var body: some View {
        ZStack {
            // Layer 1: Deep space gradient background
            LinearGradient(
                colors: [
                    Color(hex: "050510"),
                    Color(hex: "0A0A1A"),
                    Color(hex: "12122A")
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Layer 2: Aurora wave effects
            AuroraWaves()

            // Layer 3: Floating particles
            HeaderParticles()

            // Layer 4: Shimmer sweep effect
            shimmerEffect

            // Layer 5: Content
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    // Left: Menu button
                    HamburgerMenuButton(isOpen: $appState.isDrawerOpen)

                    // Center: Branding (takes remaining space)
                    brandingCenter
                        .frame(maxWidth: .infinity)

                    // Right: Action buttons
                    actionButtons
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)

                Spacer()

                // Bottom edge glow line
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                ColorPalette.primary.opacity(0),
                                ColorPalette.primary.opacity(glowPulse ? 0.6 : 0.3),
                                ColorPalette.accent.opacity(glowPulse ? 0.6 : 0.3),
                                ColorPalette.primary.opacity(0)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 2)
                    .blur(radius: 1)
            }
        }
        .frame(height: 80)
        .onAppear {
            startAnimations()
        }
    }

    // MARK: - Shimmer Effect
    private var shimmerEffect: some View {
        GeometryReader { geo in
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0),
                            Color.white.opacity(0.03),
                            Color.white.opacity(0.08),
                            Color.white.opacity(0.03),
                            Color.white.opacity(0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 150)
                .offset(x: shimmerOffset)
                .blur(radius: 20)
        }
    }

    // MARK: - Branding Center
    private var brandingCenter: some View {
        ZStack {
            // Glow behind text
            Text("DreamSculpt")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(ColorPalette.primary)
                .blur(radius: glowPulse ? 18 : 12)
                .opacity(0.5)

            VStack(spacing: 2) {
                HStack(spacing: 10) {
                    // Animated icon (smaller, inline)
                    ZStack {
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [ColorPalette.primary, ColorPalette.accent],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                            .frame(width: 32, height: 32)
                            .opacity(glowPulse ? 0.6 : 0.3)
                            .scaleEffect(glowPulse ? 1.15 : 1.0)

                        Image(systemName: appState.isLoading ? "circle.dotted" : "sparkles")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [ColorPalette.primary, ColorPalette.accent, Color.white],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .rotationEffect(.degrees(sparkleRotation))
                            .shadow(color: ColorPalette.primary.opacity(0.8), radius: 6)
                    }

                    Text("DreamSculpt")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color.white,
                                    ColorPalette.primary.opacity(0.9),
                                    ColorPalette.accent
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .shadow(color: ColorPalette.primary.opacity(0.5), radius: 4)
                }

                Text("Sketch your imagination")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(ColorPalette.textMuted)
                    .tracking(1.5)
            }
        }
        .layoutPriority(1)
    }

    // MARK: - Action Buttons
    private var actionButtons: some View {
        HStack(spacing: 8) {
            LoadImageButton(selectedImage: $appState.baseImage)

            if appState.baseImage != nil {
                clearImageButton
            }
        }
    }

    private var clearImageButton: some View {
        Button {
            HapticManager.shared.lightTap()
            withAnimation {
                appState.baseImage = nil
            }
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(
                    LinearGradient(
                        colors: [Color.red.opacity(0.8), Color.red.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(12)
                .shadow(color: Color.red.opacity(0.3), radius: 8, x: 0, y: 4)
        }
    }

    // MARK: - Animations
    private func startAnimations() {
        // Sparkle rotation
        let duration = appState.isLoading ? 1.0 : 4.0
        withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
            sparkleRotation = 360
        }

        // Shimmer sweep
        withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: false)) {
            shimmerOffset = 500
        }

        // Glow pulse
        withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
            glowPulse = true
        }
    }
}

// MARK: - Aurora Waves
struct AuroraWaves: View {
    @State private var phase1: CGFloat = 0
    @State private var phase2: CGFloat = 0
    @State private var phase3: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Wave 1 - Purple/Blue
                AuroraWavePath(phase: phase1, amplitude: 15, frequency: 1.5)
                    .fill(
                        LinearGradient(
                            colors: [
                                ColorPalette.primary.opacity(0.3),
                                ColorPalette.accent.opacity(0.2),
                                ColorPalette.primary.opacity(0.1)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .blur(radius: 20)
                    .offset(y: 20)

                // Wave 2 - Cyan/Purple
                AuroraWavePath(phase: phase2, amplitude: 12, frequency: 2.0)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "06B6D4").opacity(0.2),
                                ColorPalette.primary.opacity(0.15),
                                Color(hex: "06B6D4").opacity(0.1)
                            ],
                            startPoint: .trailing,
                            endPoint: .leading
                        )
                    )
                    .blur(radius: 25)
                    .offset(y: 10)

                // Wave 3 - Pink accent
                AuroraWavePath(phase: phase3, amplitude: 10, frequency: 2.5)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "EC4899").opacity(0.15),
                                ColorPalette.accent.opacity(0.1),
                                Color(hex: "EC4899").opacity(0.05)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .blur(radius: 30)
                    .offset(y: 30)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                    phase1 = .pi * 2
                }
                withAnimation(.easeInOut(duration: 5).repeatForever(autoreverses: true)) {
                    phase2 = .pi * 2
                }
                withAnimation(.easeInOut(duration: 6).repeatForever(autoreverses: true)) {
                    phase3 = .pi * 2
                }
            }
        }
    }
}

// MARK: - Aurora Wave Path
struct AuroraWavePath: Shape {
    var phase: CGFloat
    var amplitude: CGFloat
    var frequency: CGFloat

    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let midY = rect.height / 2

        path.move(to: CGPoint(x: 0, y: rect.height))

        for x in stride(from: 0, through: rect.width, by: 2) {
            let relativeX = x / rect.width
            let sine = sin((relativeX * frequency * .pi * 2) + phase)
            let y = midY + (sine * amplitude)
            path.addLine(to: CGPoint(x: x, y: y))
        }

        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.closeSubpath()

        return path
    }
}

// MARK: - Header Particle Model
struct HeaderParticle: Identifiable {
    let id = UUID()
    var position: CGPoint
    var size: CGFloat
    var color: Color
    var baseOpacity: Double
    var animationDuration: Double
    var animationDelay: Double
    var driftX: CGFloat
    var driftY: CGFloat
}

// MARK: - Header Particles View
struct HeaderParticles: View {
    @State private var particles: [HeaderParticle] = []
    @State private var isAnimating = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles) { particle in
                    Circle()
                        .fill(particle.color)
                        .frame(width: particle.size, height: particle.size)
                        .position(
                            x: particle.position.x + (isAnimating ? particle.driftX : 0),
                            y: particle.position.y + (isAnimating ? particle.driftY : 0)
                        )
                        .opacity(isAnimating ? particle.baseOpacity : particle.baseOpacity * 0.2)
                        .blur(radius: particle.size / 2.5)
                        .animation(
                            Animation
                                .easeInOut(duration: particle.animationDuration)
                                .repeatForever(autoreverses: true)
                                .delay(particle.animationDelay),
                            value: isAnimating
                        )
                }
            }
            .onAppear {
                generateParticles(in: geo.size)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isAnimating = true
                }
            }
        }
    }

    private func generateParticles(in size: CGSize) {
        let particleCount = Int.random(in: 18...25)
        let colors: [Color] = [
            ColorPalette.primary.opacity(0.5),
            ColorPalette.accent.opacity(0.4),
            Color(hex: "06B6D4").opacity(0.35),
            Color(hex: "EC4899").opacity(0.3),
            Color.white.opacity(0.4)
        ]

        particles = (0..<particleCount).map { _ in
            HeaderParticle(
                position: CGPoint(
                    x: CGFloat.random(in: 0...size.width),
                    y: CGFloat.random(in: 0...size.height)
                ),
                size: CGFloat.random(in: 4...20),
                color: colors.randomElement() ?? ColorPalette.primary.opacity(0.5),
                baseOpacity: Double.random(in: 0.3...0.6),
                animationDuration: Double.random(in: 3.0...6.0),
                animationDelay: Double.random(in: 0...2.0),
                driftX: CGFloat.random(in: -20...20),
                driftY: CGFloat.random(in: -10...10)
            )
        }
    }
}

// MARK: - Legacy Alias
typealias CanvasHeader = AuroraHeader

#Preview {
    ZStack {
        Color(hex: "0F0F23")
        VStack {
            AuroraHeader()
            Spacer()
        }
    }
    .ignoresSafeArea()
    .environmentObject(AppState())
}
