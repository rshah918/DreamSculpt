//
//  CameraLiveView.swift
//  DreamSculpt
//

import SwiftUI
import AVFoundation

struct CameraLiveView: UIViewRepresentable {
    var onCapture: (UIImage) -> Void
    var onCameraReady: () -> Void = {}
    @Binding var triggerCapture: Bool
    @Binding var triggerFlip: Bool
    @Binding var zoomFactor: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture, onCameraReady: onCameraReady)
    }

    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        context.coordinator.setup(in: view)
        return view
    }

    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {
        if triggerCapture {
            context.coordinator.capturePhoto()
            DispatchQueue.main.async { triggerCapture = false }
        }
        if triggerFlip {
            context.coordinator.flipCamera()
            DispatchQueue.main.async { triggerFlip = false }
        }
        context.coordinator.applyZoom(zoomFactor)
    }

    static func dismantleUIView(_ uiView: CameraPreviewUIView, coordinator: Coordinator) {
        coordinator.stopSession()
    }

    // MARK: - Preview UIView

    class CameraPreviewUIView: UIView {
        var previewLayer: AVCaptureVideoPreviewLayer?
        override func layoutSubviews() {
            super.layoutSubviews()
            previewLayer?.frame = bounds
        }
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, AVCapturePhotoCaptureDelegate {
        let onCapture: (UIImage) -> Void
        let onCameraReady: () -> Void
        private var session: AVCaptureSession?
        private var photoOutput: AVCapturePhotoOutput?
        private var currentDevice: AVCaptureDevice?
        private var currentPosition: AVCaptureDevice.Position = .back
        private var lastAppliedZoom: CGFloat = 1.0

        init(onCapture: @escaping (UIImage) -> Void, onCameraReady: @escaping () -> Void) {
            self.onCapture = onCapture
            self.onCameraReady = onCameraReady
        }

        func setup(in view: CameraPreviewUIView) {
            #if targetEnvironment(simulator)
            DispatchQueue.main.async {
                view.backgroundColor = UIColor(white: 0.08, alpha: 1)
                let icon = UIImageView(image: UIImage(systemName: "camera.fill"))
                icon.tintColor = UIColor.white.withAlphaComponent(0.25)
                icon.contentMode = .scaleAspectFit
                icon.translatesAutoresizingMaskIntoConstraints = false
                view.addSubview(icon)
                NSLayoutConstraint.activate([
                    icon.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                    icon.centerYAnchor.constraint(equalTo: view.centerYAnchor),
                    icon.widthAnchor.constraint(equalToConstant: 56),
                    icon.heightAnchor.constraint(equalToConstant: 56)
                ])
                self.onCameraReady()
            }
            #else
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                guard granted else { return }
                DispatchQueue.global(qos: .userInitiated).async {
                    self?.startSession(in: view)
                }
            }
            #endif
        }

        /// Prefers virtual multi-lens device for automatic lens switching via zoom.
        private func bestDevice(position: AVCaptureDevice.Position) -> AVCaptureDevice? {
            if position == .back {
                let types: [AVCaptureDevice.DeviceType] = [
                    .builtInTripleCamera,
                    .builtInDualWideCamera,
                    .builtInDualCamera,
                    .builtInWideAngleCamera
                ]
                return AVCaptureDevice.DiscoverySession(
                    deviceTypes: types, mediaType: .video, position: .back
                ).devices.first
            } else {
                return AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
            }
        }

        private func startSession(in view: CameraPreviewUIView) {
            let session = AVCaptureSession()
            session.sessionPreset = .photo

            guard let device = bestDevice(position: .back),
                  let input = try? AVCaptureDeviceInput(device: device),
                  session.canAddInput(input) else { return }

            session.addInput(input)
            currentDevice = device

            let output = AVCapturePhotoOutput()
            guard session.canAddOutput(output) else { return }
            session.addOutput(output)

            let previewLayer = AVCaptureVideoPreviewLayer(session: session)
            previewLayer.videoGravity = .resizeAspectFill

            DispatchQueue.main.async { [weak self] in
                previewLayer.frame = view.bounds
                view.layer.addSublayer(previewLayer)
                view.previewLayer = previewLayer
                self?.onCameraReady()
            }

            self.session = session
            self.photoOutput = output
            session.startRunning()
        }

        func capturePhoto() {
            #if targetEnvironment(simulator)
            let size = CGSize(width: 512, height: 512)
            let img = UIGraphicsImageRenderer(size: size).image { ctx in
                UIColor.systemPurple.withAlphaComponent(0.6).setFill()
                ctx.fill(CGRect(origin: .zero, size: size))
            }
            DispatchQueue.main.async { self.onCapture(img) }
            #else
            guard let photoOutput else { return }
            photoOutput.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
            #endif
        }

        func flipCamera() {
            guard let session else { return }
            let newPosition: AVCaptureDevice.Position = currentPosition == .back ? .front : .back
            currentPosition = newPosition
            lastAppliedZoom = 1.0

            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self else { return }
                session.beginConfiguration()
                session.inputs.forEach { session.removeInput($0) }

                guard let device = self.bestDevice(position: newPosition),
                      let input = try? AVCaptureDeviceInput(device: device),
                      session.canAddInput(input) else {
                    session.commitConfiguration()
                    return
                }

                session.addInput(input)
                self.currentDevice = device
                session.commitConfiguration()
            }
        }

        /// Applies zoom, clamped to the device's supported range. No-op if delta is tiny.
        func applyZoom(_ factor: CGFloat) {
            guard let device = currentDevice,
                  abs(factor - lastAppliedZoom) > 0.04 else { return }
            lastAppliedZoom = factor
            do {
                try device.lockForConfiguration()
                let clamped = max(device.minAvailableVideoZoomFactor,
                                  min(device.activeFormat.videoMaxZoomFactor, factor))
                device.videoZoomFactor = clamped
                device.unlockForConfiguration()
            } catch {}
        }

        func stopSession() {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.session?.stopRunning()
                self?.session = nil
            }
        }

        func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
            guard let data = photo.fileDataRepresentation(),
                  let raw = UIImage(data: data) else { return }
            let normalized = raw.normalizedOrientation()
            DispatchQueue.main.async { self.onCapture(normalized) }
        }
    }
}

// MARK: - UIImage orientation helper

private extension UIImage {
    func normalizedOrientation() -> UIImage {
        guard imageOrientation != .up else { return self }
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: CGRect(origin: .zero, size: size))
        let result = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return result ?? self
    }
}
