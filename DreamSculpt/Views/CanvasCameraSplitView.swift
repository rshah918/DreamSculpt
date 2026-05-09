//
//  CanvasCameraSplitView.swift
//  DreamSculpt
//

import SwiftUI

struct CanvasCameraSplitView<Content: View>: View {
    @Binding var isSplitOpen: Bool
    var onImagePicked: (UIImage, BaseImageSource) -> Void
    @ViewBuilder var content: () -> Content

    @State private var splitFraction: CGFloat = 0.0
    @State private var dragStartFraction: CGFloat = 0.0
    @State private var isDragging = false
    @State private var showCamera = false
    @State private var hasPulsed = false
    @State private var pulseGeneration: Int = 0
    @State private var isPulsing = false
    /// When the panel is open, the tab sits on the panel side of the divider so it
    /// reads as "pull right to close". Toggled only at snap, so it animates cleanly.
    @State private var tabOnPanelSide: Bool = false

    private let tabWidth: CGFloat = 22

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                // Canvas always at full width — avoids PencilKit resize artifacts
                content()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .overlay(
                        Color.black
                            .opacity(Double(splitFraction) * 0.4)
                            .allowsHitTesting(false)
                    )

                // Subtle right-edge glow in canvas mode — hints at the hidden camera panel.
                // Fades out as the panel opens; gently breathes to stay inviting.
                LinearGradient(
                    colors: [.clear, ColorPalette.primary.opacity(0.18)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 72)
                .frame(maxHeight: .infinity, alignment: .trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .opacity(Double(max(0, 1 - splitFraction / 0.15)))
                .allowsHitTesting(false)

                // "Sketch" label — placed BEFORE the camera panel so the
                // panel slides in over it as the user drags.
                modeLabel(icon: "pencil", text: "Sketch")
                    .position(x: dividerX(geo) / 2, y: geo.size.height * 0.25)
                    .opacity(isDragging ? 1 : 0)
                    .animation(.easeInOut(duration: 0.18), value: isDragging)
                    .allowsHitTesting(false)

                // Camera panel slides in from the right.
                // Width snapped to whole pixels — subpixel widths cause edge re-sampling
                // every frame, which reads as jitter on the panel boundary.
                // Always kept in the view tree (no opacity gating) so the teaser
                // layer is rasterised before the panel first slides in — otherwise
                // the drawer's rounded top corners briefly show the canvas behind
                // for a frame or two when the CTA pulse begins.
                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    CameraRightPanel(
                        showCamera: showCamera,
                        onImagePicked: handleImagePicked
                    )
                    .frame(width: max(0, (geo.size.width * splitFraction).rounded()))
                    .clipped()
                }

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

                // "Edit Photo" label — stays ABOVE the camera panel so it
                // reads on the panel area as the panel slides in.
                modeLabel(icon: "camera.fill", text: "Edit Photo")
                    .position(
                        x: dividerX(geo) + geo.size.width * splitFraction / 2,
                        y: geo.size.height * 0.25
                    )
                    .opacity(isDragging && splitFraction > 0.25 ? 1 : 0)
                    .animation(.easeInOut(duration: 0.18), value: isDragging)
                    .allowsHitTesting(false)

                // Drag tab — sits flush against the divider; flips to the panel side when open
                DividerTabView(splitFraction: splitFraction, isDragging: isDragging, onPanelSide: tabOnPanelSide)
                    .position(x: handleX(geo), y: geo.size.height * 0.45)
                    .onTapGesture {
                        // Tap doesn't open the panel — but it demos the
                        // motion so the user learns "this is a drag handle"
                        // instead of thinking it's broken.
                        performTapHint()
                    }
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
        // Snap to whole pixels — the divider is a 2pt vertical line that visually
        // shimmers if positioned at fractional X during animation.
        (geo.size.width * (1.0 - splitFraction)).rounded()
    }

    private func handleX(_ geo: GeometryProxy) -> CGFloat {
        // Tab sits flush against the divider — on the canvas side when closed, on
        // the panel side when open. During pulse and normal drag the tab tracks the
        // divider exactly so the gap between them is constant. Pixel-snapped to
        // avoid subpixel jitter during continuous drags.
        let dx = dividerX(geo)
        let half = tabWidth / 2
        let raw: CGFloat
        if tabOnPanelSide {
            raw = min(geo.size.width - half, dx + half)
        } else {
            raw = max(half, dx - half)
        }
        return raw.rounded()
    }

    // MARK: - Snap helpers

    private func snapToCamera() {
        HapticManager.shared.mediumImpact()
        withAnimation(.spring(response: 0.42, dampingFraction: 0.72)) {
            splitFraction = 1.0
            tabOnPanelSide = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.easeInOut(duration: 0.5)) { showCamera = true }
        }
    }

    private func snapToCanvas() {
        withAnimation(.spring(response: 0.42, dampingFraction: 0.72)) {
            splitFraction = 0.0
            tabOnPanelSide = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            isSplitOpen = false
            showCamera = false
            restoreCanvasFirstResponder()
        }
    }

    private func handleImagePicked(_ image: UIImage, _ source: BaseImageSource) {
        onImagePicked(image, source)
        withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
            splitFraction = 0.0
            tabOnPanelSide = false
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

    // MARK: - Tap hint (single short peek so a tap-on-the-grabber teaches
    // the user "this is a drag handle, drag it open to see the panel")

    private func performTapHint() {
        pulseGeneration += 1
        let gen = pulseGeneration
        let peek: CGFloat = 0.18
        let step: Double = 0.28
        let pause: Double = 0.18

        HapticManager.shared.lightTap()
        guard !isDragging else { return }
        // Hide the tool picker for the duration of the hint peek.
        resignCanvasFirstResponder()
        isPulsing = true
        withAnimation(.easeInOut(duration: step)) { splitFraction = peek }
        DispatchQueue.main.asyncAfter(deadline: .now() + step + pause) {
            guard pulseGeneration == gen, !isDragging else { return }
            withAnimation(.easeInOut(duration: step)) { splitFraction = 0 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + step * 2 + pause) {
            guard pulseGeneration == gen else { return }
            isPulsing = false
            restoreCanvasFirstResponder()
        }
    }

    // MARK: - Startup pulse (entire panel peeks in as CTA)

    private func performPulse() {
        pulseGeneration += 1
        let gen = pulseGeneration
        let peek: CGFloat = 0.20   // panel peeks 30% of screen width
        let step: Double = 0.70    // slower in/out
        let pause: Double = 0.55   // linger before retreating
        let cycle = step * 2 + pause

        // Hide the PencilKit tool picker for the duration of the pulse —
        // its floating UI clashes with the panel peeking in.
        resignCanvasFirstResponder()

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

        // Restore tool picker after all 3 cycles finish.
        DispatchQueue.main.asyncAfter(deadline: .now() + cycle * 3) {
            guard pulseGeneration == gen else { return }
            restoreCanvasFirstResponder()
        }
    }
}

// MARK: - Divider Tab

private struct DividerTabView: View {
    var splitFraction: CGFloat
    var isDragging: Bool
    var onPanelSide: Bool

    /// Normalised 0→1: how far the icon has morphed from chevron to camera
    private var iconProgress: CGFloat {
        min(1, max(0, (splitFraction - 0.25) / 0.4))
    }

    private var roundedCorners: UIRectCorner {
        onPanelSide ? [.topRight, .bottomRight] : [.topLeft, .bottomLeft]
    }

    var body: some View {
        ZStack {
            // Open-direction chevron when closed (points left toward panel),
            // close-direction chevron when open (points right back toward canvas).
            Image(systemName: onPanelSide ? "chevron.right" : "chevron.left")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
                .opacity(Double(1 - iconProgress))
                .scaleEffect(1 - iconProgress * 0.3)

            Image(systemName: "camera.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
                .opacity(Double(iconProgress))
                .scaleEffect(0.7 + iconProgress * 0.3)
        }
        .frame(width: 22, height: 50)
        .background(
            RoundedCorner(radius: 8, corners: roundedCorners)
                .fill(
                    LinearGradient(
                        colors: [ColorPalette.accent, ColorPalette.primary],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        )
        .overlay(
            RoundedCorner(radius: 8, corners: roundedCorners)
                .stroke(Color.white.opacity(0.25), lineWidth: 1)
        )
        .shadow(color: ColorPalette.primary.opacity(isDragging ? 0.95 : 0.65),
                radius: isDragging ? 18 : 10)
        .scaleEffect(isDragging ? 1.06 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.65), value: isDragging)
    }
}
