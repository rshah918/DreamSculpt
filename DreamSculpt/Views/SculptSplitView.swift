//
//  SculptSplitView.swift
//  DreamSculpt
//

import SwiftUI

struct SculptSplitView<Content: View>: View {
    @Binding var isSplitOpen: Bool
    var onImagePicked: (UIImage) -> Void
    @ViewBuilder var content: () -> Content

    @State private var splitFraction: CGFloat = 0.0
    @State private var dragStartFraction: CGFloat = 0.0
    @State private var isDragging = false
    @State private var showCamera = false
    @State private var hasPulsed = false
    @State private var pulseGeneration: Int = 0
    @State private var edgeGlowBreathing = false
    @State private var isPulsing = false

    private let pillHalfWidth: CGFloat = 18

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                // Canvas always at full width — avoids PencilKit resize artifacts
                content()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Subtle right-edge glow in canvas mode — hints at the hidden camera panel.
                // Fades out as the panel opens; gently breathes to stay inviting.
                LinearGradient(
                    colors: [.clear, ColorPalette.primary.opacity(edgeGlowBreathing ? 0.28 : 0.10)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 72)
                .frame(maxHeight: .infinity, alignment: .trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .opacity(Double(max(0, 1 - splitFraction / 0.15)))
                .allowsHitTesting(false)

                // Camera panel slides in from the right
                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    CameraRightPanel(
                        showCamera: showCamera,
                        onImagePicked: handleImagePicked
                    )
                    .frame(width: max(0, geo.size.width * splitFraction))
                    .clipped()
                }
                .opacity(splitFraction > 0.01 ? 1 : 0)

                // Purple glow halo on both sides of the divider
                // Suppressed during CTA pulse so the line doesn't lead the panel edge
                if splitFraction > 0.01 && !isPulsing {
                    HStack(spacing: 0) {
                        LinearGradient(
                            colors: [.clear, ColorPalette.primary.opacity(0.18)],
                            startPoint: .leading, endPoint: .trailing
                        )
                        .frame(width: 24)
                        LinearGradient(
                            colors: [ColorPalette.primary.opacity(0.18), .clear],
                            startPoint: .leading, endPoint: .trailing
                        )
                        .frame(width: 24)
                    }
                    .frame(height: geo.size.height)
                    .position(x: dividerX(geo), y: geo.size.height / 2)
                    .allowsHitTesting(false)

                    Rectangle()
                        .fill(ColorPalette.primary)
                        .frame(width: 2, height: geo.size.height)
                        .shadow(color: ColorPalette.primary.opacity(0.9), radius: 8)
                        .shadow(color: ColorPalette.primary.opacity(0.5), radius: 20)
                        .position(x: dividerX(geo), y: geo.size.height / 2)
                        .allowsHitTesting(false)
                }

                // Mode labels — appear while dragging, vanish on release
                ZStack {
                    modeLabel(icon: "pencil", text: "Sketch")
                        .position(x: dividerX(geo) / 2, y: geo.size.height * 0.25)

                    modeLabel(icon: "camera.fill", text: "Edit Photo")
                        .position(
                            x: dividerX(geo) + geo.size.width * splitFraction / 2,
                            y: geo.size.height * 0.25
                        )
                        .opacity(splitFraction > 0.25 ? 1 : 0)
                }
                .opacity(isDragging ? 1 : 0)
                .animation(.easeInOut(duration: 0.18), value: isDragging)
                .allowsHitTesting(false)

                // Drag handle — always fully on-screen, icon morphs with splitFraction
                DividerHandleView(splitFraction: splitFraction, isDragging: isDragging)
                    .position(x: handleX(geo), y: geo.size.height * 0.45)
                    .gesture(
                        DragGesture(minimumDistance: 1, coordinateSpace: .global)
                            .onChanged { value in
                                if !isDragging {
                                    isDragging = true
                                    dragStartFraction = splitFraction
                                    pulseGeneration += 1  // cancel any in-flight pulse
                                    HapticManager.shared.lightTap()
                                    resignCanvasFirstResponder()
                                }
                                let newFraction = dragStartFraction - value.translation.width / geo.size.width
                                splitFraction = max(0, min(1, newFraction))
                                isSplitOpen = splitFraction > 0.01
                            }
                            .onEnded { _ in
                                isDragging = false
                                if splitFraction >= 0.5 {
                                    snapToCamera()
                                } else {
                                    snapToCanvas()
                                }
                            }
                    )
            }
            .onAppear {
                // Gentle breathing on the edge glow
                withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                    edgeGlowBreathing = true
                }
                guard !hasPulsed else { return }
                hasPulsed = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                    performPulse()
                }
            }
        }
    }

    // MARK: - Mode label

    @ViewBuilder
    private func modeLabel(icon: String, text: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
            Text(text)
                .font(.system(size: 17, weight: .bold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(Capsule().fill(Color.black.opacity(0.45)))
        )
        .shadow(color: .black.opacity(0.5), radius: 10)
    }

    // MARK: - Position helpers

    private func dividerX(_ geo: GeometryProxy) -> CGFloat {
        geo.size.width * (1.0 - splitFraction)
    }

    private func handleX(_ geo: GeometryProxy) -> CGFloat {
        max(pillHalfWidth, min(geo.size.width - pillHalfWidth, dividerX(geo)))
    }

    // MARK: - Snap helpers

    private func snapToCamera() {
        HapticManager.shared.mediumImpact()
        withAnimation(.spring(response: 0.42, dampingFraction: 0.72)) {
            splitFraction = 1.0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.easeInOut(duration: 0.5)) { showCamera = true }
        }
    }

    private func snapToCanvas() {
        withAnimation(.spring(response: 0.42, dampingFraction: 0.72)) {
            splitFraction = 0.0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            isSplitOpen = false
            showCamera = false
            restoreCanvasFirstResponder()
        }
    }

    private func handleImagePicked(_ image: UIImage) {
        onImagePicked(image)
        withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
            splitFraction = 0.0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            showCamera = false
            isSplitOpen = false
            restoreCanvasFirstResponder()
        }
    }

    // MARK: - PKToolPicker focus management

    private func resignCanvasFirstResponder() {
        canvasView()?.resignFirstResponder()
    }

    private func restoreCanvasFirstResponder() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            canvasView()?.becomeFirstResponder()
        }
    }

    private func canvasView() -> UIView? {
        UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow })?
            .rootViewController?.view.viewWithTag(200)
    }

    // MARK: - Startup pulse (entire panel peeks in as CTA)

    private func performPulse() {
        pulseGeneration += 1
        let gen = pulseGeneration
        let peek: CGFloat = 0.30   // panel peeks 30% of screen width
        let step: Double = 0.70    // slower in/out
        let pause: Double = 0.55   // linger before retreating
        let cycle = step * 2 + pause

        for i in 0..<3 {
            let base = Double(i) * cycle
            DispatchQueue.main.asyncAfter(deadline: .now() + base) {
                guard pulseGeneration == gen, !isDragging else { return }
                isPulsing = true
                withAnimation(.easeInOut(duration: step)) { splitFraction = peek }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + base + step) {
                guard pulseGeneration == gen, !isDragging else { return }
                withAnimation(.easeInOut(duration: step)) { splitFraction = 0 }
            }
            // Clear isPulsing after each cycle retreats fully
            DispatchQueue.main.asyncAfter(deadline: .now() + base + step * 2) {
                guard pulseGeneration == gen else { return }
                isPulsing = false
            }
        }
    }
}

// MARK: - Divider Handle Pill

private struct DividerHandleView: View {
    var splitFraction: CGFloat
    var isDragging: Bool

    /// Normalised 0→1: how far the icon has morphed from chevron to camera
    private var iconProgress: CGFloat {
        min(1, max(0, (splitFraction - 0.25) / 0.4))
    }

    var body: some View {
        VStack(spacing: 7) {
            // Chevron fades out, camera icon fades in as panel opens
            ZStack {
                Image(systemName: "chevron.left")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .opacity(Double(1 - iconProgress))
                    .scaleEffect(1 - iconProgress * 0.3)

                Image(systemName: "camera.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .opacity(Double(iconProgress))
                    .scaleEffect(0.7 + iconProgress * 0.3)
            }
            .frame(width: 16, height: 14)

            VStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { _ in
                    Capsule()
                        .fill(Color.white.opacity(0.72))
                        .frame(width: 14, height: 2)
                }
            }
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 13)
        .background(
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [ColorPalette.accent, ColorPalette.primary],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        )
        .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1))
        .shadow(color: ColorPalette.primary.opacity(isDragging ? 0.95 : 0.65),
                radius: isDragging ? 18 : 10)
        .scaleEffect(isDragging ? 1.06 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.65), value: isDragging)
    }
}
