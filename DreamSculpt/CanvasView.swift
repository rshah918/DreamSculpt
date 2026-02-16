//
//  CanvasView.swift
//  DreamSculpt
//

import SwiftUI
import UIKit
import PencilKit

// MARK: - Mock Mode Toggle (DELETE LATER)
let USE_MOCK_GENERATION = true

struct CanvasView: UIViewRepresentable {
    @Binding var generatedImage: UIImage?
    @Binding var isLoading: Bool
    var baseImage: UIImage?
    var showPaperTexture: Bool
    var customPrompt: String
    var generationSettings: GenerationSettings
    var onGenerationComplete: ((UIImage, UIImage) -> Void)?
    var clearCanvasAction: (() -> Void)?
    let toolPicker = PKToolPicker()

    func makeUIView(context: Context) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = .white

        // Paper texture background view (layer behind everything)
        let textureView = UIImageView()
        textureView.contentMode = .scaleAspectFill
        textureView.translatesAutoresizingMaskIntoConstraints = false
        textureView.tag = 50
        textureView.alpha = 0.15
        containerView.addSubview(textureView)

        // Background image view (layer behind canvas)
        let backgroundImageView = UIImageView()
        backgroundImageView.contentMode = .scaleAspectFit
        backgroundImageView.translatesAutoresizingMaskIntoConstraints = false
        backgroundImageView.tag = 100
        containerView.addSubview(backgroundImageView)

        // Canvas view on top
        let canvasView = PKCanvasView()
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.drawingPolicy = .anyInput
        canvasView.translatesAutoresizingMaskIntoConstraints = false
        canvasView.tag = 200
        containerView.addSubview(canvasView)
        toolPicker.setVisible(true, forFirstResponder: canvasView)
        toolPicker.addObserver(canvasView)

        // Store references in coordinator
        context.coordinator.canvasView = canvasView
        context.coordinator.backgroundImageView = backgroundImageView
        context.coordinator.textureView = textureView

        // Set delegate
        canvasView.delegate = context.coordinator

        // Constraints
        NSLayoutConstraint.activate([
            textureView.topAnchor.constraint(equalTo: containerView.topAnchor),
            textureView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            textureView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            textureView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),

            backgroundImageView.topAnchor.constraint(equalTo: containerView.topAnchor),
            backgroundImageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            backgroundImageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            backgroundImageView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),

            canvasView.topAnchor.constraint(equalTo: containerView.topAnchor),
            canvasView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            canvasView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            canvasView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])

        // Set initial paper texture
        if showPaperTexture {
            textureView.image = PaperTextureGenerator.generate(size: CGSize(width: 512, height: 512))
        }

        return containerView
    }

    func updateUIView(_ containerView: UIView, context: Context) {
        // Update background image if changed
        if let imageView = containerView.viewWithTag(100) as? UIImageView {
            imageView.image = baseImage
        }

        // Update paper texture visibility
        if let textureView = containerView.viewWithTag(50) as? UIImageView {
            textureView.alpha = showPaperTexture ? 0.15 : 0
            if showPaperTexture && textureView.image == nil {
                textureView.image = PaperTextureGenerator.generate(size: CGSize(width: 512, height: 512))
            }
        }

        // Update coordinator reference
        context.coordinator.parent = self
        
        DispatchQueue.main.async {
            guard let canvasView = context.coordinator.canvasView else { return }

            toolPicker.setVisible(true, forFirstResponder: canvasView)

            // If promptbar was editing text, canvas lost first responder.
            // This safely restores it.
            if !canvasView.isFirstResponder {
                canvasView.becomeFirstResponder()
            }

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
        private var checkTimer: Timer?

        init(_ parent: CanvasView) {
            self.parent = parent
            super.init()

            // Start a timer to check for pending requests after strokes end
            checkTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                self?.checkAndSendPendingRequest()
            }
        }

        deinit {
            checkTimer?.invalidate()
        }

        func getResizedImageMaintainingAspect(from drawing: PKDrawing, targetSize: CGSize = CGSize(width: 170.666666667, height: 170.666666667)) -> UIImage {
            let originalImage = drawing.image(from: drawing.bounds, scale: 1.0)
            let originalSize = originalImage.size

            let widthRatio = targetSize.width / originalSize.width
            let heightRatio = targetSize.height / originalSize.height
            let scale = min(widthRatio, heightRatio)

            let newSize = CGSize(width: originalSize.width * scale, height: originalSize.height * scale)
            let origin = CGPoint(x: (targetSize.width - newSize.width) / 2,
                                 y: (targetSize.height - newSize.height) / 2)

            UIGraphicsBeginImageContextWithOptions(targetSize, false, 0)

            UIColor.white.setFill()
            UIRectFill(CGRect(origin: .zero, size: targetSize))

            originalImage.draw(in: CGRect(origin: origin, size: newSize))

            let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()

            return resizedImage!
        }

        func getCompositeImage(from drawing: PKDrawing, targetSize: CGSize = CGSize(width: 170.666666667, height: 170.666666667)) -> UIImage {
            UIGraphicsBeginImageContextWithOptions(targetSize, false, 0)

            // Fill with white background
            UIColor.white.setFill()
            UIRectFill(CGRect(origin: .zero, size: targetSize))

            // Draw background image if present
            if let baseImage = parent.baseImage {
                let baseSize = baseImage.size
                let widthRatio = targetSize.width / baseSize.width
                let heightRatio = targetSize.height / baseSize.height
                let scale = min(widthRatio, heightRatio)
                let newSize = CGSize(width: baseSize.width * scale, height: baseSize.height * scale)
                let origin = CGPoint(x: (targetSize.width - newSize.width) / 2,
                                     y: (targetSize.height - newSize.height) / 2)
                baseImage.draw(in: CGRect(origin: origin, size: newSize))
            }

            // Draw the canvas strokes on top
            if !drawing.bounds.isEmpty {
                let drawingImage = drawing.image(from: drawing.bounds, scale: 1.0)
                let drawingSize = drawingImage.size
                let widthRatio = targetSize.width / drawingSize.width
                let heightRatio = targetSize.height / drawingSize.height
                let scale = min(widthRatio, heightRatio)
                let newSize = CGSize(width: drawingSize.width * scale, height: drawingSize.height * scale)
                let origin = CGPoint(x: (targetSize.width - newSize.width) / 2,
                                     y: (targetSize.height - newSize.height) / 2)
                drawingImage.draw(in: CGRect(origin: origin, size: newSize))
            }

            let compositeImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()

            return compositeImage!
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            // Always store the latest drawing
            pendingDrawing = canvasView.drawing
        }

        func canvasViewDidBeginUsingTool(_ canvasView: PKCanvasView) {
            debounceManager.strokeBegan()
        }
        
        func canvasViewDidEndUsingTool(_ canvasView: PKCanvasView) {
            debounceManager.strokeEnded()
        }
        
        private func checkAndSendPendingRequest() {
            guard let drawing = pendingDrawing else { return }
            guard !drawing.bounds.isEmpty else { return }
            guard debounceManager.shouldAllowRequest() else { return }

            // Clear pending since we're sending
            pendingDrawing = nil

            let currentSketch = getCompositeImage(from: drawing)
            let prompt = parent.customPrompt
            let settings = parent.generationSettings

            Task { @MainActor in
                parent.isLoading = true
                HapticManager.shared.generationStarted()
            }

            Task {
                let result: UIImage?

                if USE_MOCK_GENERATION {
                    // MOCK: Generate a random gradient image after a short delay
                    result = await MockImageGenerator.generateRandomImage()
                } else {
                    result = await uploadDrawing(image: currentSketch, prompt: prompt, settings: settings)
                }

                if let result = result {
                    await MainActor.run {
                        self.parent.generatedImage = result
                        self.parent.isLoading = false
                        self.parent.onGenerationComplete?(currentSketch, result)
                        HapticManager.shared.generationCompleted()
                    }
                } else {
                    await MainActor.run {
                        self.parent.isLoading = false
                        HapticManager.shared.generationFailed()
                    }
                }
            }
        }

        func clearCanvas() {
            canvasView?.drawing = PKDrawing()
            pendingDrawing = nil
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

// MARK: - Paper Texture Generator
enum PaperTextureGenerator {
    static func generate(size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, true, 1.0)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }

        // Off-white base color
        let baseColor = UIColor(red: 0.98, green: 0.97, blue: 0.95, alpha: 1.0)
        context.setFillColor(baseColor.cgColor)
        context.fill(CGRect(origin: .zero, size: size))

        // Add noise pattern for paper texture
        for _ in 0..<Int(size.width * size.height / 50) {
            let x = CGFloat.random(in: 0...size.width)
            let y = CGFloat.random(in: 0...size.height)
            let dotSize = CGFloat.random(in: 0.5...2.0)

            let grayValue = CGFloat.random(in: 0.85...0.95)
            let dotColor = UIColor(white: grayValue, alpha: CGFloat.random(in: 0.1...0.3))
            context.setFillColor(dotColor.cgColor)
            context.fillEllipse(in: CGRect(x: x, y: y, width: dotSize, height: dotSize))
        }

        // Add subtle fiber lines
        for _ in 0..<20 {
            let startX = CGFloat.random(in: 0...size.width)
            let startY = CGFloat.random(in: 0...size.height)
            let endX = startX + CGFloat.random(in: -30...30)
            let endY = startY + CGFloat.random(in: -5...5)

            context.setStrokeColor(UIColor(white: 0.9, alpha: 0.2).cgColor)
            context.setLineWidth(0.5)
            context.move(to: CGPoint(x: startX, y: startY))
            context.addLine(to: CGPoint(x: endX, y: endY))
            context.strokePath()
        }

        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return image
    }
}
