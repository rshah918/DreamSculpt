//
//  CanvasView.swift
//  DreamSculpt
//
//  Created by Rahul Shah on 8/31/25.
//

import SwiftUI
import UIKit
import PencilKit


struct CanvasView: UIViewRepresentable {
    private let canvasView = PKCanvasView()
    private let toolPicker = PKToolPicker()
    @Binding var image: UIImage?
    
    func makeUIView(context: Context) -> PKCanvasView {
        // Allow finger drawing
        canvasView.drawingPolicy = .anyInput
        // Make the tool picker visible
        toolPicker.setVisible(true, forFirstResponder: canvasView)
        // Make the canvas respond to tool changes
        toolPicker.addObserver(canvasView)
        // Make the canvas active -- first responder
        canvasView.becomeFirstResponder()
        // Attach canvas listener
        canvasView.delegate = context.coordinator
        
        return canvasView
    }
    
    func updateUIView(_ canvasView: PKCanvasView, context: Context) {
    }

    class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: CanvasView
        
        init(_ parent: CanvasView) {
            self.parent = parent
        }
        
        func getResizedImageMaintainingAspect(from drawing: PKDrawing, targetSize: CGSize = CGSize(width: 170.666666667, height: 170.666666667)) -> UIImage {
            // Original drawing image
            let originalImage = drawing.image(from: drawing.bounds, scale: 1.0)
            let originalSize = originalImage.size
            
            // Calculate aspect-fit size
            let widthRatio = targetSize.width / originalSize.width
            let heightRatio = targetSize.height / originalSize.height
            let scale = min(widthRatio, heightRatio)
            
            let newSize = CGSize(width: originalSize.width * scale, height: originalSize.height * scale)
            let origin = CGPoint(x: (targetSize.width - newSize.width) / 2,
                                 y: (targetSize.height - newSize.height) / 2)
            
            // Start context (opaque = false ensures fill is respected)
            UIGraphicsBeginImageContextWithOptions(targetSize, false, 0)
            
            // Fill with white background
            UIColor.white.setFill()
            UIRectFill(CGRect(origin: .zero, size: targetSize))
            
            // Draw the original image centered
            originalImage.draw(in: CGRect(origin: origin, size: newSize))
            
            let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            return resizedImage!
        }
        
        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            let currentSketch = getResizedImageMaintainingAspect(from: canvasView.drawing)
            Task {
                parent.image = await uploadDrawing(image: currentSketch) ?? parent.image
            }
            
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
}
