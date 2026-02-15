//
//  SplashView.swift
//  DreamSculpt
//

import SwiftUI

struct SplashView: View {
    // MARK: - Animation State
    @State private var logoScale: CGFloat = 0.62
    @State private var logoOpacity: Double = 0
    @State private var logoFloat: CGFloat = 14

    @State private var titleOffset: CGFloat = 18
    @State private var titleOpacity: Double = 0
    @State private var subtitleOpacity: Double = 0

    @State private var ringRotation1: Double = 0
    @State private var ringRotation2: Double = 0
    @State private var ringScale: CGFloat = 0.9

    @State private var showParticles: Bool = false
    @State private var shimmerPhase: CGFloat = -0.9

    @State private var backgroundShift: CGFloat = 0

    // Spark burst
    @State private var showSparkBurst: Bool = false
    @State private var sparkSeed: Int = 0

    // Morph
    @State private var morphOut: Bool = false
    @State private var morphBlur: Double = 0

    let onComplete: () -> Void

    var body: some View {
        ZStack {
            // MARK: - Cinematic Background (now includes floating blobs)
            CinematicBackground(shift: backgroundShift)
                .ignoresSafeArea()

            // MARK: - Particles
            if showParticles {
                FloatingParticlesView()
                    .transition(.opacity)
            }

            // MARK: - Bottom Horizon Glow (keeps the lower half alive)
            BottomHorizonGlow()
                .opacity(0.85)
                .blendMode(.screen)
                .ignoresSafeArea()

            // MARK: - Content
            VStack(spacing: 18) {
                Spacer()

                // MARK: - Logo Cluster
                ZStack {
                    // Bloom behind everything
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    ColorPalette.accent.opacity(0.22),
                                    ColorPalette.primary.opacity(0.12),
                                    .clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 150
                            )
                        )
                        .frame(width: 300, height: 300)
                        .blur(radius: 18)
                        .opacity(logoOpacity)

                    // Orbit ring 1
                    Circle()
                        .stroke(
                            AngularGradient(
                                colors: [
                                    ColorPalette.primary.opacity(0.18),
                                    ColorPalette.accent.opacity(0.95),
                                    ColorPalette.primary.opacity(0.18),
                                    ColorPalette.accent.opacity(0.65)
                                ],
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 2, lineCap: .round)
                        )
                        .frame(width: 176, height: 176)
                        .rotationEffect(.degrees(ringRotation1))
                        .scaleEffect(ringScale)
                        .opacity(logoOpacity * 0.7)
                        .blur(radius: 1.2)

                    // Orbit ring 2 (dashed)
                    Circle()
                        .stroke(
                            AngularGradient(
                                colors: [
                                    .white.opacity(0.04),
                                    ColorPalette.primary.opacity(0.55),
                                    ColorPalette.accent.opacity(0.9),
                                    .white.opacity(0.04)
                                ],
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [7, 11])
                        )
                        .frame(width: 144, height: 144)
                        .rotationEffect(.degrees(ringRotation2))
                        .scaleEffect(ringScale)
                        .opacity(logoOpacity * 0.55)
                        .blur(radius: 1.8)

                    // Glass plate
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    ColorPalette.surface.opacity(0.95),
                                    ColorPalette.background.opacity(0.9)
                                ],
                                center: .topLeading,
                                startRadius: 0,
                                endRadius: 120
                            )
                        )
                        .frame(width: 124, height: 124)
                        .overlay(
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            .white.opacity(0.28),
                                            .white.opacity(0.06),
                                            ColorPalette.glassBorder.opacity(0.45)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                        .shadow(color: Color.black.opacity(0.55), radius: 28, x: 0, y: 18)
                        .shadow(color: ColorPalette.accent.opacity(0.18), radius: 18, x: 0, y: 0)

                    // Custom mark
                    DreamSculptMark()
                        .frame(width: 56, height: 56)
                        .shadow(color: ColorPalette.accent.opacity(0.55), radius: 18, x: 0, y: 0)
                        .shadow(color: ColorPalette.primary.opacity(0.25), radius: 10, x: 0, y: 0)
                        .overlay(
                            DreamSculptMark()
                                .frame(width: 56, height: 56)
                                .foregroundStyle(.white.opacity(0.12))
                                .blur(radius: 0.4)
                                .offset(x: -0.7, y: -0.7)
                        )

                    // Spark burst
                    if showSparkBurst {
                        SparkBurst(seed: sparkSeed)
                            .frame(width: 240, height: 240)
                            .transition(.opacity)
                            .allowsHitTesting(false)
                    }
                }
                .scaleEffect(logoScale)
                .opacity(logoOpacity)
                .offset(y: -logoFloat)
                .blur(radius: morphBlur)
                .scaleEffect(morphOut ? 1.08 : 1.0)
                .opacity(morphOut ? 0.0 : 1.0)

                // MARK: - Premium Title
                VStack(spacing: 10) {
                    PremiumTitle(
                        text: "DreamSculpt",
                        opacity: titleOpacity,
                        shimmerPhase: shimmerPhase
                    )
                    .offset(y: titleOffset)
                    .opacity(titleOpacity)
                    .blur(radius: morphBlur)
                    .scaleEffect(morphOut ? 1.05 : 1.0)
                    .opacity(morphOut ? 0.0 : 1.0)

                    Text("Sketch your imagination")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(ColorPalette.textMuted.opacity(0.95))
                        .opacity(subtitleOpacity)
                        .blur(radius: morphBlur)
                        .opacity(morphOut ? 0.0 : subtitleOpacity)
                }

                Spacer(minLength: 54)
            }
            .padding(.horizontal, 22)

            // MARK: - Morph overlay
            MorphOverlay(isActive: morphOut)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
        .onAppear { startAnimation() }
    }

    // MARK: - Animation Timeline
    private func startAnimation() {
        // Background drift
        withAnimation(.easeInOut(duration: 10).repeatForever(autoreverses: true)) {
            backgroundShift = 1
        }

        // Entrance
        withAnimation(.spring(response: 0.85, dampingFraction: 0.62).delay(0.05)) {
            logoScale = 1.0
            logoOpacity = 1.0
            ringScale = 1.0
        }

        // Float loop
        withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true).delay(0.85)) {
            logoFloat = -10
        }

        // Rings
        withAnimation(.linear(duration: 10).repeatForever(autoreverses: false).delay(0.2)) {
            ringRotation1 = 360
        }
        withAnimation(.linear(duration: 6).repeatForever(autoreverses: false).delay(0.2)) {
            ringRotation2 = -360
        }

        // Particles
        withAnimation(.easeIn(duration: 0.4).delay(0.25)) {
            showParticles = true
        }

        // Title
        withAnimation(.spring(response: 0.7, dampingFraction: 0.85).delay(0.35)) {
            titleOffset = 0
            titleOpacity = 1
        }

        // Subtitle
        withAnimation(.easeOut(duration: 0.55).delay(0.55)) {
            subtitleOpacity = 1
        }

        // Shimmer sweep
        withAnimation(.easeInOut(duration: 1.2).delay(0.85)) {
            shimmerPhase = 0.95
        }

        // Spark burst right as title lands
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            sparkSeed += 1
            showSparkBurst = true
            withAnimation(.easeOut(duration: 0.55).delay(0.45)) {
                showSparkBurst = false
            }
        }

        // Morph out
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.05) {
            withAnimation(.easeInOut(duration: 0.5)) {
                morphOut = true
                morphBlur = 12
            }
        }

        // Complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.45) {
            onComplete()
        }
    }
}

#Preview {
    SplashView(onComplete: {})
}

// MARK: - Premium Title

private struct PremiumTitle: View {
    let text: String
    let opacity: Double
    let shimmerPhase: CGFloat

    var body: some View {
        ZStack {
            // Base fill
            Text(text)
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            .white,
                            .white.opacity(0.86)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            // Subtle inner glow / highlight
            Text(text)
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            ColorPalette.accent.opacity(0.45),
                            .clear,
                            ColorPalette.primary.opacity(0.35)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .blendMode(.screen)
                .opacity(0.6)

            // Soft shadow for depth
            Text(text)
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundColor(.clear)
                .shadow(color: Color.black.opacity(0.6), radius: 18, x: 0, y: 14)

            // Shimmer pass
            Text(text)
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            .clear,
                            .white.opacity(0.55),
                            .clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .mask(
                    Rectangle()
                        .fill(Color.white)
                        .rotationEffect(.degrees(18))
                        .offset(x: shimmerPhase * 360)
                )
                .blendMode(.screen)
                .opacity(opacity)
        }
        .drawingGroup() // makes gradients/glows look smoother
    }
}

// MARK: - Background (with floating blobs)

private struct CinematicBackground: View {
    var shift: CGFloat

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hex: "070714"),
                    Color(hex: "0D0D22"),
                    Color(hex: "050512")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // MARK: - Floating Aurora Blobs (fills dead space beautifully)
            FloatingBlob(
                size: 560,
                color: ColorPalette.primary.opacity(0.16),
                x: -210 + shift * 55,
                y: -260 + shift * 20,
                blur: 80
            )

            FloatingBlob(
                size: 520,
                color: ColorPalette.accent.opacity(0.14),
                x: 230 - shift * 60,
                y: -110 + shift * 30,
                blur: 85
            )

            FloatingBlob(
                size: 620,
                color: ColorPalette.primary.opacity(0.11),
                x: 40 + shift * 35,
                y: 340 - shift * 45,
                blur: 100
            )

            FloatingBlob(
                size: 420,
                color: ColorPalette.accent.opacity(0.10),
                x: -170 + shift * 25,
                y: 260 - shift * 20,
                blur: 90
            )

            // Vignette
            RadialGradient(
                colors: [
                    .clear,
                    Color.black.opacity(0.70)
                ],
                center: .center,
                startRadius: 80,
                endRadius: 560
            )
            .blendMode(.multiply)

            // Subtle grain
            NoiseOverlay()
                .opacity(0.06)
                .blendMode(.overlay)
        }
        .drawingGroup()
    }
}

private struct FloatingBlob: View {
    let size: CGFloat
    let color: Color
    let x: CGFloat
    let y: CGFloat
    let blur: CGFloat

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .blur(radius: blur)
            .offset(x: x, y: y)
            .blendMode(.screen)
    }
}

// MARK: - Bottom Horizon Glow

private struct BottomHorizonGlow: View {
    var body: some View {
        VStack {
            Spacer()
            Rectangle()
                .fill(
                    RadialGradient(
                        colors: [
                            ColorPalette.accent.opacity(0.20),
                            ColorPalette.primary.opacity(0.12),
                            .clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 520
                    )
                )
                .frame(height: 360)
                .blur(radius: 26)
                .offset(y: 80)
        }
    }
}

// MARK: - Noise

private struct NoiseOverlay: View {
    var body: some View {
        Canvas { context, size in
            let count = 1200
            for _ in 0..<count {
                let x = CGFloat.random(in: 0...size.width)
                let y = CGFloat.random(in: 0...size.height)
                let r = CGFloat.random(in: 0.4...1.2)
                let a = Double.random(in: 0.02...0.08)
                context.fill(
                    Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)),
                    with: .color(.white.opacity(a))
                )
            }
        }
    }
}

// MARK: - Floating Particles

private struct FloatingParticlesView: View {
    @State private var particles: [FloatingParticle] = []
    @State private var isAnimating = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles) { p in
                    Circle()
                        .fill(p.color)
                        .frame(width: p.size, height: p.size)
                        .position(p.position)
                        .blur(radius: p.size * 0.6)
                        .opacity(p.opacity)
                }
            }
            .onAppear {
                if particles.isEmpty {
                    createParticles(in: geo.size)
                }
                animate(in: geo.size)
            }
        }
        .ignoresSafeArea()
    }

    private func createParticles(in size: CGSize) {
        let count = 30
        particles = (0..<count).map { _ in
            FloatingParticle(
                position: CGPoint(
                    x: CGFloat.random(in: 0...size.width),
                    y: CGFloat.random(in: 0...size.height)
                ),
                size: CGFloat.random(in: 2...7),
                opacity: Double.random(in: 0.07...0.22),
                color: [
                    ColorPalette.primary.opacity(0.35),
                    ColorPalette.accent.opacity(0.35),
                    Color.white.opacity(0.18)
                ].randomElement()!
            )
        }
    }

    private func animate(in size: CGSize) {
        guard !isAnimating else { return }
        isAnimating = true

        for i in particles.indices {
            let duration = Double.random(in: 4.5...9.0)
            let delay = Double.random(in: 0.0...1.4)

            let dx = CGFloat.random(in: -55...55)
            let dy = CGFloat.random(in: -80...80)

            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
                    particles[i].position.x = min(max(0, particles[i].position.x + dx), size.width)
                    particles[i].position.y = min(max(0, particles[i].position.y + dy), size.height)
                    particles[i].opacity = Double.random(in: 0.07...0.25)
                }
            }
        }
    }
}

private struct FloatingParticle: Identifiable {
    let id = UUID()
    var position: CGPoint
    var size: CGFloat
    var opacity: Double
    var color: Color
}

// MARK: - Custom Logo Mark

private struct DreamSculptMark: View {
    var body: some View {
        ZStack {
            // Sculpted "D"
            Path { path in
                path.move(to: CGPoint(x: 12, y: 10))
                path.addCurve(to: CGPoint(x: 12, y: 46),
                              control1: CGPoint(x: 10, y: 18),
                              control2: CGPoint(x: 10, y: 38))

                path.addCurve(to: CGPoint(x: 34, y: 44),
                              control1: CGPoint(x: 14, y: 52),
                              control2: CGPoint(x: 26, y: 50))

                path.addCurve(to: CGPoint(x: 44, y: 28),
                              control1: CGPoint(x: 42, y: 40),
                              control2: CGPoint(x: 48, y: 34))

                path.addCurve(to: CGPoint(x: 34, y: 12),
                              control1: CGPoint(x: 40, y: 20),
                              control2: CGPoint(x: 42, y: 14))

                path.addCurve(to: CGPoint(x: 12, y: 10),
                              control1: CGPoint(x: 26, y: 8),
                              control2: CGPoint(x: 16, y: 8))
            }
            .stroke(
                LinearGradient(
                    colors: [
                        ColorPalette.accent.opacity(0.95),
                        ColorPalette.primary.opacity(0.95),
                        .white.opacity(0.85)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                style: StrokeStyle(lineWidth: 4.2, lineCap: .round, lineJoin: .round)
            )
            .blur(radius: 0.15)

            // Inner highlight
            Path { path in
                path.move(to: CGPoint(x: 16, y: 14))
                path.addCurve(to: CGPoint(x: 16, y: 42),
                              control1: CGPoint(x: 14, y: 22),
                              control2: CGPoint(x: 14, y: 36))
                path.addCurve(to: CGPoint(x: 32, y: 40),
                              control1: CGPoint(x: 18, y: 46),
                              control2: CGPoint(x: 26, y: 44))
            }
            .stroke(Color.white.opacity(0.18), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
            .blur(radius: 0.2)

            // Spark star
            SparkStar()
                .frame(width: 18, height: 18)
                .offset(x: 18, y: -18)
        }
        .frame(width: 56, height: 56)
    }
}

private struct SparkStar: View {
    var body: some View {
        ZStack {
            Capsule()
                .fill(Color.white.opacity(0.9))
                .frame(width: 3, height: 18)
            Capsule()
                .fill(Color.white.opacity(0.65))
                .frame(width: 18, height: 3)

            Capsule()
                .fill(ColorPalette.accent.opacity(0.85))
                .frame(width: 3, height: 12)
                .rotationEffect(.degrees(45))

            Capsule()
                .fill(ColorPalette.primary.opacity(0.75))
                .frame(width: 12, height: 3)
                .rotationEffect(.degrees(45))
        }
        .blur(radius: 0.15)
    }
}

// MARK: - Spark Burst

private struct SparkBurst: View {
    let seed: Int
    @State private var progress: CGFloat = 0

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let rays = 18

            for i in 0..<rays {
                let angle = (CGFloat(i) / CGFloat(rays)) * (.pi * 2)
                let length = 40 + CGFloat((i * 37 + seed * 19) % 28)
                let width = CGFloat.random(in: 1.2...2.4)

                var path = Path()
                path.move(to: center)

                let end = CGPoint(
                    x: center.x + cos(angle) * length * progress,
                    y: center.y + sin(angle) * length * progress
                )

                path.addLine(to: end)

                context.stroke(
                    path,
                    with: .linearGradient(
                        Gradient(colors: [
                            Color.white.opacity(0.0),
                            Color.white.opacity(0.75),
                            ColorPalette.accent.opacity(0.55),
                            Color.white.opacity(0.0)
                        ]),
                        startPoint: center,
                        endPoint: end
                    ),
                    lineWidth: width
                )
            }
        }
        .blur(radius: 0.8)
        .opacity(Double(1 - progress))
        .onAppear {
            progress = 0
            withAnimation(.easeOut(duration: 0.45)) {
                progress = 1
            }
        }
    }
}

// MARK: - Morph Overlay

private struct MorphOverlay: View {
    var isActive: Bool

    var body: some View {
        ZStack {
            if isActive {
                Rectangle()
                    .fill(
                        RadialGradient(
                            colors: [
                                ColorPalette.accent.opacity(0.12),
                                Color.black.opacity(0.88)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 600
                        )
                    )
                    .transition(.opacity)
                    .blur(radius: 2)
            }
        }
        .animation(.easeInOut(duration: 0.45), value: isActive)
    }
}
