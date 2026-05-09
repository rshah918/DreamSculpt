//
//  CanvasView.swift
//  DreamSculpt
//

import SwiftUI
import UIKit
import PencilKit

// MARK: - Mock Mode Toggle
#if DEBUG
let USE_MOCK_GENERATION = true
#else
let USE_MOCK_GENERATION = false
#endif

struct CanvasView: UIViewRepresentable {
    @Binding var generatedImage: UIImage?
    @Binding var isLoading: Bool
    var baseImage: UIImage?
    var sessionId: String
    var customPrompt: String
    var generationSettings: GenerationSettings
    var onGenerationComplete: ((UIImage, UIImage) -> Void)?
    @Binding var triggerGeneration: (() -> Void)?
    var onDrawingChanged: ((Bool) -> Void)?
    var onCanUndoChanged: ((Bool) -> Void)?
    var onStrokeCountChanged: ((Int) -> Void)?
    @Binding var requestFocus: (() -> Void)?
    @Binding var undoAction: (() -> Void)?
    @Binding var clearAction: (() -> Void)?
    @Binding var resignFocus: (() -> Void)?
    var canvasReady: Bool = true
    var pencilOnlyMode: Bool = false

    func makeUIView(context: Context) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = .white

        // Background image
        let backgroundImageView = UIImageView()
        backgroundImageView.contentMode = .scaleAspectFit
        backgroundImageView.translatesAutoresizingMaskIntoConstraints = false
        backgroundImageView.tag = 100
        containerView.addSubview(backgroundImageView)

        // Canvas
        let canvasView = PKCanvasView()
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.drawingPolicy = pencilOnlyMode ? .pencilOnly : .anyInput
        canvasView.translatesAutoresizingMaskIntoConstraints = false
        canvasView.tag = 200
        containerView.addSubview(canvasView)

        // Restore the persisted drawing (if any) before installing the delegate
        // so the load doesn't trigger a redundant save on the next change.
        if let restored = Coordinator.loadPersistedDrawing() {
            canvasView.drawing = restored
        }

        // Coordinator references
        context.coordinator.canvasView = canvasView
        context.coordinator.backgroundImageView = backgroundImageView
        // Baseline for undo-button visibility. Strokes restored from disk
        // aren't in PencilKit's undo manager, so they don't count as undoable.
        context.coordinator.strokesAtLaunch = canvasView.drawing.strokes.count

        canvasView.delegate = context.coordinator

        // Surface initial hasDrawing state so the prompt bar's clear button
        // appears immediately after a restore.
        let initialHasDrawing = !canvasView.drawing.bounds.isEmpty
        Task { @MainActor in
            self.onDrawingChanged?(initialHasDrawing)
        }

        // Constraints - background image has bottom inset to avoid prompt bar occlusion
        NSLayoutConstraint.activate([
            backgroundImageView.topAnchor.constraint(equalTo: containerView.topAnchor),
            backgroundImageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            backgroundImageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            backgroundImageView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -200),

            canvasView.topAnchor.constraint(equalTo: containerView.topAnchor),
            canvasView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            canvasView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            canvasView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])

        return containerView
    }

    func updateUIView(_ containerView: UIView, context: Context) {
        // Update background
        if let imageView = containerView.viewWithTag(100) as? UIImageView {
            imageView.image = baseImage
        }

        // Update coordinator reference
        context.coordinator.parent = self

        // React to pencil-only mode toggle in Settings without rebuilding the view.
        if let canvasView = context.coordinator.canvasView {
            let desiredPolicy: PKCanvasViewDrawingPolicy = pencilOnlyMode ? .pencilOnly : .anyInput
            if canvasView.drawingPolicy != desiredPolicy {
                canvasView.drawingPolicy = desiredPolicy
            }
        }

        // Attach tool picker once canvas is in window and canvas is ready
        DispatchQueue.main.async {
            guard let canvasView = context.coordinator.canvasView,
                  canvasView.window != nil,
                  self.canvasReady,
                  context.coordinator.toolPicker == nil else { return }

            let toolPicker = PKToolPicker()
            toolPicker.setVisible(true, forFirstResponder: canvasView)
            toolPicker.addObserver(canvasView)
            canvasView.becomeFirstResponder()
            context.coordinator.toolPicker = toolPicker
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: CanvasView
        weak var canvasView: PKCanvasView?
        weak var backgroundImageView: UIImageView?
        weak var textureView: UIImageView?
        var toolPicker: PKToolPicker?

        private let debounceManager = DebounceManager.shared
        private var pendingDrawing: PKDrawing?
        private var saveDebounceItem: DispatchWorkItem?
        /// Last `hasDrawing` value we forwarded to SwiftUI. Used to skip
        /// no-op `onDrawingChanged` calls during a stroke, which would
        /// otherwise invalidate ContentView state on every PencilKit tick.
        private var lastReportedHasDrawing: Bool?
        /// Last `canUndo` value we forwarded to SwiftUI. Computed as
        /// `currentStrokes > strokesAtLaunch` so the prompt bar can hide
        /// its undo button when there's nothing to undo (notably at first
        /// launch with a restored drawing — assigning `canvasView.drawing`
        /// directly bypasses the undo manager).
        private var lastReportedCanUndo: Bool?
        /// Last stroke count forwarded to SwiftUI. Lets the prompt bar
        /// gate the trash button on >=2 strokes.
        private var lastReportedStrokeCount: Int?
        /// Number of strokes present immediately after restoring from
        /// disk. PencilKit's undo manager only knows about strokes the
        /// user added in this session — anything <= this baseline can't
        /// actually be undone. Resets to 0 after `clearAction`.
        var strokesAtLaunch: Int = 0

        private static var persistedDrawingURL: URL {
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            return docs.appendingPathComponent("canvas.drawing")
        }

        static func loadPersistedDrawing() -> PKDrawing? {
            let url = persistedDrawingURL
            guard FileManager.default.fileExists(atPath: url.path),
                  let data = try? Data(contentsOf: url),
                  let drawing = try? PKDrawing(data: data) else { return nil }
            return drawing
        }

        static func deletePersistedDrawing() {
            try? FileManager.default.removeItem(at: persistedDrawingURL)
        }

        private func schedulePersist(_ drawing: PKDrawing) {
            saveDebounceItem?.cancel()
            let item = DispatchWorkItem {
                try? drawing.dataRepresentation().write(to: Coordinator.persistedDrawingURL, options: .atomic)
            }
            saveDebounceItem = item
            // 1.2s debounce — fires after the user pauses; canvasViewDidEndUsingTool
            // already let us know the stroke completed, so this just batches bursts.
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 1.2, execute: item)
        }

        init(_ parent: CanvasView) {
            self.parent = parent
            super.init()

            // Wire up external triggers
            Task { @MainActor in
                self.parent.triggerGeneration = { [weak self] in
                    self?.performGeneration()
                }
                self.parent.requestFocus = { [weak self] in
                    self?.canvasView?.becomeFirstResponder()
                }
                self.parent.undoAction = { [weak self] in
                    self?.canvasView?.undoManager?.undo()
                    self?.notifyCanUndoChanged()
                }
                self.parent.clearAction = { [weak self] in
                    guard let canvasView = self?.canvasView else { return }
                    canvasView.drawing = PKDrawing()
                    // Drop the undo history too — otherwise PencilKit retains
                    // every stroke the user just cleared, potentially many MBs
                    // of vector data, indefinitely.
                    canvasView.undoManager?.removeAllActions()
                    self?.pendingDrawing = nil
                    self?.saveDebounceItem?.cancel()
                    self?.lastReportedHasDrawing = false
                    // Reset the launch baseline — the user's next stroke
                    // becomes the first undoable one again.
                    self?.strokesAtLaunch = 0
                    Coordinator.deletePersistedDrawing()
                    self?.parent.onDrawingChanged?(false)
                    self?.notifyCanUndoChanged()
                    self?.notifyStrokeCountChanged(0)
                }
                self.parent.resignFocus = { [weak self] in
                    self?.canvasView?.resignFirstResponder()
                }
            }
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            pendingDrawing = canvasView.drawing
            // strokes.isEmpty is O(1); drawing.bounds is O(n) over every stroke.
            // This callback fires continuously during a stroke (60+/sec on
            // ProMotion), so the cheap check matters.
            let hasDrawing = !canvasView.drawing.strokes.isEmpty
            // Only forward to SwiftUI when the value actually flips. Otherwise
            // we invalidate ContentView state on every PencilKit tick.
            if hasDrawing != lastReportedHasDrawing {
                lastReportedHasDrawing = hasDrawing
                Task { @MainActor in
                    parent.onDrawingChanged?(hasDrawing)
                }
            }
            // Also surface canUndo / strokeCount on every drawing change.
            // canvasViewDidEndUsingTool isn't always reliable (PencilKit can
            // skip it for edge cases like very short taps or tool-less
            // strokes), so we drive these from the drawing-changed callback
            // too. Both notify methods are change-detected internally, so a
            // mid-stroke tick that doesn't flip the value is a no-op.
            notifyCanUndoChanged()
            notifyStrokeCountChanged(canvasView.drawing.strokes.count)
            // Persistence is handled in canvasViewDidEndUsingTool — no point
            // re-scheduling the disk write on every mid-stroke tick.
        }

        func canvasViewDidBeginUsingTool(_ canvasView: PKCanvasView) {
            debounceManager.strokeBegan()
        }

        func canvasViewDidEndUsingTool(_ canvasView: PKCanvasView) {
            debounceManager.strokeEnded()
            // Persist on stroke completion. If the drawing was just emptied,
            // drop the stale file instead of writing an empty one.
            if canvasView.drawing.strokes.isEmpty {
                saveDebounceItem?.cancel()
                Coordinator.deletePersistedDrawing()
            } else {
                schedulePersist(canvasView.drawing)
            }
            // PencilKit just registered (or removed) an undo action for
            // this stroke — surface the new state so the prompt bar can
            // show/hide its undo button.
            notifyCanUndoChanged()
            notifyStrokeCountChanged(canvasView.drawing.strokes.count)
        }

        private func notifyStrokeCountChanged(_ count: Int) {
            guard count != lastReportedStrokeCount else { return }
            lastReportedStrokeCount = count
            Task { @MainActor in
                parent.onStrokeCountChanged?(count)
            }
        }

        private func notifyCanUndoChanged() {
            // Don't read `undoManager.canUndo` — PencilKit registers its
            // per-stroke undo action on a later runloop tick than the
            // delegate callback, so any synchronous (or even async) read
            // here was off-by-one and the button only appeared after the
            // second stroke. Comparing the live stroke count against the
            // baseline at launch gives the same answer (true iff the user
            // has added strokes this session) without the timing dance.
            let currentStrokes = canvasView?.drawing.strokes.count ?? 0
            let canUndo = currentStrokes > strokesAtLaunch
            guard canUndo != lastReportedCanUndo else { return }
            lastReportedCanUndo = canUndo
            Task { @MainActor in
                parent.onCanUndoChanged?(canUndo)
            }
        }

        func performGeneration() {
            // The Generate button is the only gate — it's `.disabled` when
            // input is empty, while loading, or when nothing has changed
            // since the last successful generation. Don't add silent
            // server-side rate limiting here: if the user tapped a live
            // button, fire the request.
            let drawing = pendingDrawing ?? PKDrawing()
            let currentSketch = getCompositeImage(from: drawing)
            let prompt = parent.customPrompt
            let settings = parent.generationSettings
            let sessionId = parent.sessionId

            Task { @MainActor in
                parent.isLoading = true
                HapticManager.shared.generationStarted()
            }

            Task {
                let result: UIImage?

                if USE_MOCK_GENERATION {
                    result = await MockImageGenerator.generateRandomImage()
                } else {
                    result = await uploadDrawing(image: currentSketch, prompt: prompt, settings: settings, sessionId: sessionId)
                }

                await MainActor.run {
                    parent.isLoading = false
                    if let result = result {
                        parent.generatedImage = result
                        parent.onGenerationComplete?(currentSketch, result)
                        HapticManager.shared.generationCompleted()
                    } else {
                        HapticManager.shared.generationFailed()
                    }
                }
            }
        }

        func clearCanvas() {
            canvasView?.drawing = PKDrawing()
            pendingDrawing = nil
        }

        func getCompositeImage(from drawing: PKDrawing, targetSize: CGSize = CGSize(width: 1024, height: 1024)) -> UIImage {
            if let baseImage = parent.baseImage,
               let composed = baseImageComposite(from: drawing, baseImage: baseImage, targetSize: targetSize) {
                return composed
            }
            return sketchOnlyComposite(from: drawing, targetSize: targetSize)
        }

        /// Composite when a base image is loaded. The output canvas is square
        /// (the API expects square input — anything else gets squashed back to
        /// square server-side and returns stretched). The base image is drawn
        /// aspect-fit inside that square (with white letterboxing), and the
        /// strokes are drawn into the same fit rect so they overlay the base
        /// at the position the user actually drew them on screen.
        private func baseImageComposite(from drawing: PKDrawing, baseImage: UIImage, targetSize: CGSize) -> UIImage? {
            guard let bgFrame = backgroundImageView?.frame,
                  bgFrame.width > 0, bgFrame.height > 0 else { return nil }

            // Where the base image is actually displayed inside the background
            // image view (aspect-fit). The image view shares the canvas's
            // coordinate space, so this rect is also valid in canvas coords.
            let canvasFit = min(bgFrame.width / baseImage.size.width,
                                bgFrame.height / baseImage.size.height)
            let canvasDisplayed = CGSize(width: baseImage.size.width * canvasFit,
                                         height: baseImage.size.height * canvasFit)
            let baseDisplayRect = CGRect(
                x: bgFrame.midX - canvasDisplayed.width / 2,
                y: bgFrame.midY - canvasDisplayed.height / 2,
                width: canvasDisplayed.width,
                height: canvasDisplayed.height
            )

            // Square output. Aspect-fit the base image inside it.
            let outputSide = max(targetSize.width, targetSize.height)
            let outputSize = CGSize(width: outputSide, height: outputSide)
            let outputFit = min(outputSide / baseImage.size.width,
                                outputSide / baseImage.size.height)
            let baseInOutput = CGSize(width: baseImage.size.width * outputFit,
                                      height: baseImage.size.height * outputFit)
            let baseInOutputRect = CGRect(
                x: (outputSide - baseInOutput.width) / 2,
                y: (outputSide - baseInOutput.height) / 2,
                width: baseInOutput.width,
                height: baseInOutput.height
            )

            // scale: 1.0 — render exactly outputSide×outputSide pixels, not
            // multiplied by device DPI. We control upload resolution explicitly.
            UIGraphicsBeginImageContextWithOptions(outputSize, true, 1.0)
            UIColor.white.setFill()
            UIRectFill(CGRect(origin: .zero, size: outputSize))
            baseImage.draw(in: baseInOutputRect)

            if !drawing.bounds.isEmpty {
                // Render the slice of the canvas overlapping the displayed base
                // image, then place it into the same fit rect on the output.
                // Both rects share the base image's aspect ratio, so this is a
                // uniform scale — strokes land where the user drew them.
                let strokeImage = drawing.image(from: baseDisplayRect, scale: 1.0)
                strokeImage.draw(in: baseInOutputRect)
            }

            let composed = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            return composed
        }

        /// Pure sketch (no base image) — keep the legacy behavior of scaling the
        /// drawing's bounding box to fill the frame, since with no spatial
        /// reference the AI input is cleaner when the sketch dominates.
        private func sketchOnlyComposite(from drawing: PKDrawing, targetSize: CGSize) -> UIImage {
            UIGraphicsBeginImageContextWithOptions(targetSize, false, 1.0)
            UIColor.white.setFill()
            UIRectFill(CGRect(origin: .zero, size: targetSize))

            if !drawing.bounds.isEmpty {
                let drawingImage = drawing.image(from: drawing.bounds, scale: 1.0)
                let scale = min(targetSize.width / drawingImage.size.width,
                                targetSize.height / drawingImage.size.height)
                let newSize = CGSize(width: drawingImage.size.width * scale,
                                     height: drawingImage.size.height * scale)
                let origin = CGPoint(x: (targetSize.width - newSize.width) / 2,
                                     y: (targetSize.height - newSize.height) / 2)
                drawingImage.draw(in: CGRect(origin: origin, size: newSize))
            }

            let composite = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            return composite ?? UIImage()
        }
    }
}

// MARK: - Mock Image Generator (DELETE LATER)
enum MockImageGenerator {
    static let gradientColors: [(UIColor, UIColor, String)] = [
        (.systemBlue, .systemPurple, "Ocean"),
        (.systemOrange, .systemRed, "Sunset"),
        (.systemGreen, .systemTeal, "Forest"),
        (.systemPink, .systemIndigo, "Galaxy"),
        (.systemYellow, .systemOrange, "Desert")
    ]

    static func generateRandomImage() async -> UIImage? {
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

        let size = CGSize(width: 512, height: 512)
        let colorPair = gradientColors.randomElement()!

        UIGraphicsBeginImageContextWithOptions(size, true, 1.0)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }

        let colors = [colorPair.0.cgColor, colorPair.1.cgColor] as CFArray
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0.0, 1.0]) else { return nil }

        // Random gradient direction
        let directions: [(CGPoint, CGPoint)] = [
            (CGPoint(x: 0, y: 0), CGPoint(x: size.width, y: size.height)),
            (CGPoint(x: size.width, y: 0), CGPoint(x: 0, y: size.height)),
            (CGPoint(x: size.width/2, y: 0), CGPoint(x: size.width/2, y: size.height)),
            (CGPoint(x: 0, y: size.height/2), CGPoint(x: size.width, y: size.height/2))
        ]
        let direction = directions.randomElement()!

        context.drawLinearGradient(gradient, start: direction.0, end: direction.1, options: [])

        // Add some random shapes for variety
        let shapeCount = Int.random(in: 3...8)
        for _ in 0..<shapeCount {
            let shapeSize = CGFloat.random(in: 30...150)
            let x = CGFloat.random(in: 0...size.width - shapeSize)
            let y = CGFloat.random(in: 0...size.height - shapeSize)
            let rect = CGRect(x: x, y: y, width: shapeSize, height: shapeSize)

            context.setFillColor(UIColor.white.withAlphaComponent(CGFloat.random(in: 0.1...0.3)).cgColor)

            if Bool.random() {
                context.fillEllipse(in: rect)
            } else {
                context.fill(rect)
            }
        }

        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return image
    }
}
