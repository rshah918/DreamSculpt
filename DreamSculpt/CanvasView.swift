//
//  CanvasView.swift
//  DreamSculpt
//

import SwiftUI
import UIKit
import PencilKit

// MARK: - Mock Mode Toggle (DELETE LATER)
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
    @Binding var requestFocus: (() -> Void)?
    @Binding var undoAction: (() -> Void)?
    @Binding var clearAction: (() -> Void)?
    @Binding var resignFocus: (() -> Void)?
    var canvasReady: Bool = true
    var pencilOnlyMode: Bool = false
    var symmetryMode: SymmetryMode = .off

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
        // Seed the stroke-count tracker so symmetry mirroring only fires for
        // strokes the user adds *after* mount — not the restored ones.
        context.coordinator.trackedStrokeCount = canvasView.drawing.strokes.count

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

        /// Tracks how many strokes were in the drawing the last time we observed
        /// it. Used by symmetry mirroring to detect strokes added by the user
        /// (so we can mirror them) and to avoid re-mirroring strokes we just
        /// appended ourselves.
        var trackedStrokeCount: Int = 0

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
                }
                self.parent.clearAction = { [weak self] in
                    guard let canvasView = self?.canvasView else { return }
                    canvasView.drawing = PKDrawing()
                    self?.pendingDrawing = nil
                    self?.trackedStrokeCount = 0
                    self?.saveDebounceItem?.cancel()
                    Coordinator.deletePersistedDrawing()
                    self?.parent.onDrawingChanged?(false)
                }
                self.parent.resignFocus = { [weak self] in
                    self?.canvasView?.resignFirstResponder()
                }
            }
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            // Apply symmetry to any strokes the user just added before we
            // record the new drawing — that way the mirrored strokes are
            // captured in the persisted state and the generation snapshot.
            applySymmetryIfNeeded(on: canvasView)

            pendingDrawing = canvasView.drawing
            trackedStrokeCount = canvasView.drawing.strokes.count
            let hasDrawing = !canvasView.drawing.bounds.isEmpty
            Task { @MainActor in
                parent.onDrawingChanged?(hasDrawing)
            }
            // Persist (debounced). If the drawing was just emptied, drop any
            // stale file rather than writing an empty one.
            if hasDrawing {
                schedulePersist(canvasView.drawing)
            } else {
                saveDebounceItem?.cancel()
                Coordinator.deletePersistedDrawing()
            }
        }

        // MARK: - Symmetry mirroring

        /// If symmetry is enabled and the user has added strokes since the
        /// last change, reflect those strokes across the configured axis/axes
        /// and append the mirrors to the drawing. Updates `trackedStrokeCount`
        /// to the post-mirror total so the next callback (triggered by our own
        /// append) doesn't re-mirror them.
        private func applySymmetryIfNeeded(on canvasView: PKCanvasView) {
            let mode = parent.symmetryMode
            guard mode != .off else { return }

            let currentCount = canvasView.drawing.strokes.count
            let added = currentCount - trackedStrokeCount
            // Only mirror when strokes were *added* (not removed by undo/eraser).
            guard added > 0 else { return }

            let canvasSize = canvasView.bounds.size
            guard canvasSize.width > 0, canvasSize.height > 0 else { return }

            let userStrokes = Array(canvasView.drawing.strokes.suffix(added))
            var mirrored: [PKStroke] = []
            for stroke in userStrokes {
                switch mode {
                case .off:
                    break
                case .vertical:
                    mirrored.append(reflect(stroke, axis: .vertical, canvasSize: canvasSize))
                case .horizontal:
                    mirrored.append(reflect(stroke, axis: .horizontal, canvasSize: canvasSize))
                case .quad:
                    let v = reflect(stroke, axis: .vertical, canvasSize: canvasSize)
                    let h = reflect(stroke, axis: .horizontal, canvasSize: canvasSize)
                    let vh = reflect(v, axis: .horizontal, canvasSize: canvasSize)
                    mirrored.append(contentsOf: [v, h, vh])
                }
            }
            guard !mirrored.isEmpty else { return }

            // Pre-bump the tracked count so the synchronous re-entry triggered
            // by the append below sees `added == 0` and bails out.
            trackedStrokeCount = currentCount + mirrored.count
            canvasView.drawing.strokes.append(contentsOf: mirrored)
        }

        private enum SymmetryAxis { case vertical, horizontal }

        /// Reflect a stroke across the canvas centerline. Vertical axis mirrors
        /// left↔right; horizontal mirrors top↔bottom. The reflection is composed
        /// onto whatever transform the stroke already has (typically `.identity`
        /// for fresh user strokes, but non-identity for an already-mirrored stroke
        /// when we apply quad symmetry).
        private func reflect(_ stroke: PKStroke, axis: SymmetryAxis, canvasSize: CGSize) -> PKStroke {
            var copy = stroke
            let mirror: CGAffineTransform
            switch axis {
            case .vertical:
                // x' = width - x  →  scale x by -1, then translate by +width
                mirror = CGAffineTransform(scaleX: -1, y: 1)
                    .concatenating(CGAffineTransform(translationX: canvasSize.width, y: 0))
            case .horizontal:
                mirror = CGAffineTransform(scaleX: 1, y: -1)
                    .concatenating(CGAffineTransform(translationX: 0, y: canvasSize.height))
            }
            copy.transform = copy.transform.concatenating(mirror)
            return copy
        }

        func canvasViewDidBeginUsingTool(_ canvasView: PKCanvasView) {
            debounceManager.strokeBegan()
        }

        func canvasViewDidEndUsingTool(_ canvasView: PKCanvasView) {
            debounceManager.strokeEnded()
        }

        func performGeneration() {
            let hasDrawing = pendingDrawing != nil && !pendingDrawing!.bounds.isEmpty
            let hasBase = parent.baseImage != nil

            guard hasDrawing || hasBase else { return }
            guard debounceManager.shouldAllowRequest() else { return }

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

        func getCompositeImage(from drawing: PKDrawing, targetSize: CGSize = CGSize(width: 170.666, height: 170.666)) -> UIImage {
            UIGraphicsBeginImageContextWithOptions(targetSize, false, 0)
            UIColor.white.setFill()
            UIRectFill(CGRect(origin: .zero, size: targetSize))

            if let baseImage = parent.baseImage {
                let scale = min(targetSize.width/baseImage.size.width, targetSize.height/baseImage.size.height)
                let newSize = CGSize(width: baseImage.size.width*scale, height: baseImage.size.height*scale)
                let origin = CGPoint(x: (targetSize.width-newSize.width)/2, y: (targetSize.height-newSize.height)/2)
                baseImage.draw(in: CGRect(origin: origin, size: newSize))
            }

            if !drawing.bounds.isEmpty {
                let drawingImage = drawing.image(from: drawing.bounds, scale: 1.0)
                let scale = min(targetSize.width/drawingImage.size.width, targetSize.height/drawingImage.size.height)
                let newSize = CGSize(width: drawingImage.size.width*scale, height: drawingImage.size.height*scale)
                let origin = CGPoint(x: (targetSize.width-newSize.width)/2, y: (targetSize.height-newSize.height)/2)
                drawingImage.draw(in: CGRect(origin: origin, size: newSize))
            }

            let compositeImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            return compositeImage ?? UIImage()
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
