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
    // Static "pulsed" state — previously animated forever, but the cost of
    // continuously re-evaluating the dependent views (icon scale/opacity,
    // bottom glow) added up. Resting at the brighter end looks alive enough.
    private let glowPulse: Bool = true

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

            // Layer 4: Content
            VStack(spacing: 0) {
                HStack(alignment: .center, spacing: 12) {
                    // Left: Menu button
                    HamburgerMenuButton(isOpen: $appState.isDrawerOpen)

                    // Center: Branding (takes remaining space)
                    brandingCenter
                        .frame(maxWidth: .infinity)

                    // Right: Action buttons
                    actionButtons
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

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
        .frame(height: 110)
        .onAppear {
            startAnimations()
        }
    }

    // MARK: - Branding Center
    private var brandingCenter: some View {
        ZStack {
            // Glow behind text — static blur (animating blur radius forces Core Image
            // to recompute the kernel every frame, which is a major GPU cost).
            Text("DreamSculpt")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundColor(ColorPalette.primary)
                .blur(radius: 9)
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
                        .font(.system(size: 26, weight: .bold, design: .rounded))
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

                Text("Sculpt your imagination")
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
//            CameraButton()

            LoadImageButton()
                .opacity(appState.isSplitOpen ? 0 : 1)
                .allowsHitTesting(!appState.isSplitOpen)
                .animation(.easeInOut(duration: 0.2), value: appState.isSplitOpen)

            if appState.baseImage != nil {
                clearImageButton
            }
        }
    }

    private var clearImageButton: some View {
        Button {
            HapticManager.shared.lightTap()
            withAnimation {
                appState.setBaseImage(nil)
            }
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 36, height: 36)
                .background(
                    LinearGradient(
                        colors: [Color.red.opacity(0.8), Color.red.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(10)
                .shadow(color: Color.red.opacity(0.3), radius: 6, x: 0, y: 3)
        }
    }

    // MARK: - Animations
    private func startAnimations() {
        // Sparkle rotation — only spin while a generation is in flight, otherwise
        // it's perpetual GPU work for an effect the user isn't watching.
        if appState.isLoading {
            withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                sparkleRotation = 360
            }
        }
    }
}

// MARK: - Aurora Waves
struct AuroraWaves: View {
    // Static phases — each wave gets a different fixed offset so they don't
    // line up and look like a single shape. Animating these every frame meant
    // SwiftUI rebuilt three blurred shape paths at 60Hz, which dominated GPU
    // time. The layered + blurred result still reads as "aurora" without motion.
    private let phase1: CGFloat = 0
    private let phase2: CGFloat = .pi / 2
    private let phase3: CGFloat = .pi

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
                    .blur(radius: 12)
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
                    .blur(radius: 14)
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
                    .blur(radius: 16)
                    .offset(y: 30)
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

        // 8pt step (was 2pt) — same visible smoothness with ~4× fewer points to compute every frame.
        for x in stride(from: 0, through: rect.width, by: 8) {
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
}

// MARK: - Header Particles View
struct HeaderParticles: View {
    @State private var particles: [HeaderParticle] = []

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles) { particle in
                    Circle()
                        .fill(particle.color)
                        .frame(width: particle.size, height: particle.size)
                        .position(particle.position)
                        .opacity(particle.baseOpacity)
                        .blur(radius: particle.size / 2.5)
                }
            }
            .onAppear {
                if particles.isEmpty {
                    generateParticles(in: geo.size)
                }
            }
        }
        // Particles are decorative dots — let SwiftUI rasterize once and reuse.
        .drawingGroup()
        .allowsHitTesting(false)
    }

    private func generateParticles(in size: CGSize) {
        // Static placement — previously each particle drove its own perpetual
        // SwiftUI animation with a blur, which compounded into a steady GPU
        // load. The visual reads as "atmospheric blurred dots" either way.
        let particleCount = Int.random(in: 8...10)
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
                baseOpacity: Double.random(in: 0.3...0.6)
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
