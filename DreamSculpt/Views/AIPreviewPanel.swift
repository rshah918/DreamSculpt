//
//  AIPreviewPanel.swift
//  DreamSculpt
//

import SwiftUI

struct AIPreviewPanel: View {
    let image: UIImage?
    let isLoading: Bool
    @Binding var isExpanded: Bool
    @Binding var offset: CGSize

    // Session history for slider
    let sessionImages: [UIImage]
    @Binding var sessionIndex: Int

    // Action callbacks
    var onLoadToCanvas: ((UIImage) -> Void)? = nil
    var onSaveToPhotos: ((UIImage) -> Void)? = nil

    /// When the camera panel is open or pulsing, suppress the dismissed-state
    /// grabber so it doesn't collide with the camera divider tab.
    var hideForCameraPanel: Bool = false

    @State private var dragOffset: CGSize = .zero
    @State private var isDismissed: Bool = false
    /// y-coordinate (in this view's geo) where the restore-grabber should
    /// appear. Set on dismissal to wherever the preview was thrown off-screen,
    /// then clamped to avoid colliding with the camera divider tab.
    @State private var grabberY: CGFloat = 170

    // Pinch-to-zoom state — active only while `isExpanded`
    @State private var zoomScale: CGFloat = 1.0
    @State private var lastZoomScale: CGFloat = 1.0
    @State private var zoomPan: CGSize = .zero
    @State private var lastZoomPan: CGSize = .zero

    private let minZoom: CGFloat = 1.0
    private let maxZoom: CGFloat = 4.0

    // Only show if we have at least one image or are loading
    var shouldShow: Bool {
        image != nil || isLoading
    }

    var body: some View {
        GeometryReader { geo in
            if shouldShow {
                ZStack {
                    if isExpanded {
                        expandedOverlay(geo: geo)
                    }

                    // Conditional render with explicit `.transition(.opacity)`
                    // on each branch + an `.animation(_, value: isDismissed)`
                    // on the ZStack. This is more reliable than opacity-driven
                    // visibility for `.position`-modified views (which have
                    // zero-size layout and can stop re-animating after the
                    // first toggle when only opacity changes).
                    if !isDismissed {
                        previewContent(geo: geo)
                            .transition(.opacity)
                    }

                    if isDismissed && !hideForCameraPanel {
                        restoreGrabber(geo: geo)
                            .transition(.opacity)
                    }
                }
                .onChange(of: image) { oldImage, newImage in
                    // Auto-restore when a *different* non-nil image arrives.
                    // Guarding on identity prevents spurious restores from
                    // parent re-renders that re-pass the same UIImage.
                    guard isDismissed, let new = newImage, new !== oldImage else { return }
                    offset = .zero
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        isDismissed = false
                    }
                }
                .onChange(of: isLoading) { _, loading in
                    if loading && isDismissed {
                        offset = .zero
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            isDismissed = false
                        }
                    }
                }
                .onAppear {
                    // Recover from any previously-stored bad offset (e.g. a
                    // pre-clamp build that flung the preview off the left edge).
                    let clamped = clampedOffset(offset, in: geo)
                    if clamped != offset { offset = clamped }
                }
            }
        }
    }

    private func restoreGrabber(geo: GeometryProxy) -> some View {
        // Sits at the right edge at the y the user threw the preview off,
        // clamped to avoid the camera divider tab band. Tapping or swiping
        // left brings the preview back.
        //
        // CRITICAL: `.contentShape` and the gestures must be applied BEFORE
        // `.position(...)`. After `.position`, the view fills the parent for
        // layout, so a `.contentShape(Rectangle())` placed afterwards turns
        // into a screen-spanning hit area that swallows every touch (which
        // blocks PencilKit from receiving canvas drawings).
        Capsule()
            .fill(ColorPalette.gradientPrimary)
            .frame(width: 6, height: 56)
            .overlay(
                Image(systemName: "photo.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(ColorPalette.primary))
                    .offset(x: -16)
            )
            .shadow(color: ColorPalette.primary.opacity(0.5), radius: 8)
            .frame(width: 60, height: 88)
            .contentShape(Rectangle())
            .onTapGesture {
                HapticManager.shared.lightTap()
                offset = .zero
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    isDismissed = false
                }
            }
            .gesture(
                DragGesture()
                    .onEnded { value in
                        if value.translation.width < -30 {
                            HapticManager.shared.lightTap()
                            offset = .zero
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                isDismissed = false
                            }
                        }
                    }
            )
            .position(x: geo.size.width - 4, y: grabberY)
    }

    private func expandedOverlay(geo: GeometryProxy) -> some View {
        Color.black.opacity(0.7)
            .ignoresSafeArea()
            .onTapGesture {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    isExpanded = false
                }
            }
    }

    private func previewContent(geo: GeometryProxy) -> some View {
        let previewSize: CGFloat = isExpanded ? min(geo.size.width - 40, geo.size.height - 200) : 130
        // Default position: top-right corner of canvas (below header)
        let position = isExpanded
            ? CGPoint(x: geo.size.width / 2, y: geo.size.height / 2 - 40)
            : CGPoint(x: geo.size.width - 85, y: 170)

        return VStack(spacing: 16) {
            ZStack {
                if let uiImage = image {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(isExpanded ? zoomScale : 1.0)
                        .offset(isExpanded ? zoomPan : .zero)
                }

                if isLoading {
                    loadingOverlay
                }
            }
            .frame(width: previewSize, height: previewSize)
            .glassmorphic(cornerRadius: isExpanded ? 20 : 16)
            .clipped()
            .shadow(color: Color.black.opacity(0.3), radius: 12, x: 0, y: 8)
            .overlay(
                expandButton,
                alignment: .topTrailing
            )
            .gesture(isExpanded ? zoomAndPanGesture(maxPanFor: previewSize) : nil)
            .onTapGesture(count: 2) {
                guard isExpanded else { return }
                HapticManager.shared.lightTap()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    if zoomScale > 1.01 {
                        resetZoom()
                    } else {
                        zoomScale = 2.0
                        lastZoomScale = 2.0
                    }
                }
            }
            .onTapGesture {
                if isExpanded && zoomScale > 1.01 {
                    // Zoomed: single tap collapses zoom rather than the panel
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { resetZoom() }
                } else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        isExpanded.toggle()
                    }
                }
            }

            // History slider - only show when expanded and have multiple images
            if isExpanded && sessionImages.count > 1 {
                historySlider(width: previewSize)
            }

            // Action buttons when expanded
            if isExpanded && image != nil {
                actionButtons(width: previewSize)
            }
        }
        .offset(isExpanded ? .zero : CGSize(width: offset.width + dragOffset.width, height: offset.height + dragOffset.height))
        .position(position)
        .gesture(
            isExpanded ? nil : dragGesture(geo: geo)
        )
        .onChange(of: isExpanded) { _, expanded in
            if !expanded { resetZoom() }
        }
        .onChange(of: sessionIndex) { _, _ in
            // Switching session image — reset zoom so the new one starts at 1x
            withAnimation(.easeOut(duration: 0.2)) { resetZoom() }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isExpanded)
    }

    private func resetZoom() {
        zoomScale = 1.0
        lastZoomScale = 1.0
        zoomPan = .zero
        lastZoomPan = .zero
    }

    private func zoomAndPanGesture(maxPanFor previewSize: CGFloat) -> some Gesture {
        let magnification = MagnificationGesture()
            .onChanged { value in
                let next = lastZoomScale * value
                zoomScale = min(max(next, minZoom), maxZoom)
            }
            .onEnded { _ in
                lastZoomScale = zoomScale
                if zoomScale <= 1.01 {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { resetZoom() }
                } else {
                    zoomPan = clampedPan(zoomPan, scale: zoomScale, container: previewSize)
                    lastZoomPan = zoomPan
                }
            }

        let pan = DragGesture()
            .onChanged { value in
                guard zoomScale > 1.01 else { return }
                let raw = CGSize(
                    width: lastZoomPan.width + value.translation.width,
                    height: lastZoomPan.height + value.translation.height
                )
                zoomPan = clampedPan(raw, scale: zoomScale, container: previewSize)
            }
            .onEnded { _ in
                lastZoomPan = zoomPan
            }

        return SimultaneousGesture(magnification, pan)
    }

    /// Keeps the zoomed image's edges from dragging past the viewport edges.
    private func clampedPan(_ pan: CGSize, scale: CGFloat, container: CGFloat) -> CGSize {
        let maxOffset = max(0, container * (scale - 1) / 2)
        return CGSize(
            width: min(maxOffset, max(-maxOffset, pan.width)),
            height: min(maxOffset, max(-maxOffset, pan.height))
        )
    }

    private func historySlider(width: CGFloat) -> some View {
        VStack(spacing: 8) {
            HStack {
                Text("Session History")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white.opacity(0.8))

                Spacer()

                Text("\(sessionIndex + 1) / \(sessionImages.count)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }

            Slider(
                value: Binding(
                    get: { Double(sessionIndex) },
                    set: { sessionIndex = Int($0) }
                ),
                in: 0...Double(max(0, sessionImages.count - 1)),
                step: 1
            )
            .tint(ColorPalette.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(width: width)
        .background(Color.black.opacity(0.5))
        .cornerRadius(12)
    }

    private func actionButtons(width: CGFloat) -> some View {
        HStack(spacing: 12) {
            Button {
                if let image = image {
                    HapticManager.shared.mediumImpact()
                    onLoadToCanvas?(image)
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 12))
                    Text("Load to Canvas")
                        .font(.caption.weight(.medium))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(ColorPalette.gradientPrimary)
                .cornerRadius(10)
            }

            Button {
                if let image = image {
                    onSaveToPhotos?(image)
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 12))
                    Text("Save to Photos")
                        .font(.caption.weight(.medium))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.15))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                )
            }
        }
        .frame(width: width)
    }

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .cornerRadius(isExpanded ? 20 : 16)

            VStack(spacing: 8) {
                LoadingIndicator(size: 32, lineWidth: 3)

                Text("Generating...")
                    .font(.caption)
                    .foregroundColor(.white)
            }
        }
    }

    private var expandButton: some View {
        Group {
            if !isExpanded && image != nil {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(6)
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(6)
                    .padding(8)
            }
        }
    }

    private func dragGesture(geo: GeometryProxy) -> some Gesture {
        DragGesture()
            .onChanged { value in
                dragOffset = value.translation
            }
            .onEnded { value in
                // Two ways to dismiss, covering both intents:
                //   1. Slow slide off — the preview's final center crosses the
                //      screen's right edge (user is "moving it out of the way").
                //   2. Flick / throw — quick gesture with rightward momentum,
                //      even if the finger didn't actually travel far.
                let actual = value.translation.width
                let predicted = value.predictedEndTranslation.width
                let absHeight = abs(value.translation.height)

                let finalCenterX = (geo.size.width - 85) + offset.width + actual
                let slidPastEdge = finalCenterX > geo.size.width && actual > 0

                let momentumThrow = (actual > 60 || predicted > 100) &&
                    max(actual, predicted) > absHeight * 0.7

                let swipedOffRight = slidPastEdge || momentumThrow
                if swipedOffRight {
                    HapticManager.shared.mediumImpact()
                    let releaseY = 170 + offset.height + value.translation.height
                    grabberY = clampedGrabberY(releaseY, in: geo)
                    // Persist the throw translation into `offset` so the
                    // preview fades out at the throw position (no snap-back).
                    // `offset` is reset to .zero in every restore path before
                    // re-showing, so the next reveal starts at default.
                    offset = CGSize(
                        width: offset.width + value.translation.width,
                        height: offset.height + value.translation.height
                    )
                    dragOffset = .zero
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        isDismissed = true
                    }
                    return
                }
                // Otherwise, accept the new position but clamp so at least
                // ~50pt of the preview stays on-screen on every edge.
                let proposed = CGSize(
                    width: offset.width + value.translation.width,
                    height: offset.height + value.translation.height
                )
                let clamped = clampedOffset(proposed, in: geo)
                if clamped == proposed {
                    offset = proposed
                    dragOffset = .zero
                } else {
                    // Snap back when the user tried to fling past an edge.
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
                        offset = clamped
                        dragOffset = .zero
                    }
                }
            }
    }

    /// Keeps the grabber on-screen and out of the camera divider tab's vertical
    /// band. The camera tab sits at ~45% of the split view's height; once the
    /// AuroraHeader offset is applied, that lands near 50% of this view's geo.
    /// 65pt half-band = 25pt tab half + 28pt grabber half + 12pt buffer.
    private func clampedGrabberY(_ y: CGFloat, in geo: GeometryProxy) -> CGFloat {
        let tabCenter = geo.size.height * 0.50
        let bandHalf: CGFloat = 65
        var clamped = y
        if abs(clamped - tabCenter) < bandHalf {
            clamped = clamped < tabCenter ? tabCenter - bandHalf : tabCenter + bandHalf
        }
        return min(geo.size.height - 60, max(80, clamped))
    }

    /// Clamps the persisted preview offset so at least `minVisible` points of
    /// the unexpanded preview stay on every edge of the screen. Without this,
    /// a hard fling left would park the preview off-screen with no way to
    /// recover it (the right-edge grabber only triggers on right-flings).
    /// Default unexpanded position is (geo.width - 85, 170); preview is 130×130
    /// so its half-extent is 65.
    private func clampedOffset(_ proposed: CGSize, in geo: GeometryProxy) -> CGSize {
        let baseX = geo.size.width - 85
        let baseY: CGFloat = 170
        let half: CGFloat = 65
        let minVisible: CGFloat = 50

        // Right edge of preview ≥ minVisible AND left edge ≤ width - minVisible
        let minX = (minVisible - half) - baseX
        let maxX = (geo.size.width - minVisible + half) - baseX

        let minY = (minVisible - half) - baseY
        let maxY = (geo.size.height - minVisible + half) - baseY

        return CGSize(
            width: min(maxX, max(minX, proposed.width)),
            height: min(maxY, max(minY, proposed.height))
        )
    }
}
