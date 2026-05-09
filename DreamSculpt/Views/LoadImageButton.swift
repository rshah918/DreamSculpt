//
//  LoadImageButton.swift
//  DreamSculpt
//

import SwiftUI
import PhotosUI

struct LoadImageButton: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedItem: PhotosPickerItem? = nil

    var body: some View {
        PhotosPicker(selection: $selectedItem, matching: .images) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 36, height: 36)
                .background(
                    LinearGradient(
                        colors: [ColorPalette.primary.opacity(0.9), ColorPalette.accent.opacity(0.9)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(10)
                .shadow(color: ColorPalette.primary.opacity(0.3), radius: 6, x: 0, y: 3)
        }
        .onChange(of: selectedItem) { _, newValue in
            HapticManager.shared.lightTap()
            Task {
                if let data = try? await newValue?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run {
                        appState.setBaseImage(image, source: .library)
                    }
                }
            }
        }
    }
}

struct CameraButton: View {
    @EnvironmentObject var appState: AppState
    @State private var showCamera = false

    var body: some View {
        Button {
            HapticManager.shared.lightTap()
            showCamera = true
        } label: {
            Image(systemName: "camera.fill")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 36, height: 36)
                .background(
                    LinearGradient(
                        colors: [ColorPalette.primary.opacity(0.9), ColorPalette.accent.opacity(0.9)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(10)
                .shadow(color: ColorPalette.primary.opacity(0.3), radius: 6, x: 0, y: 3)
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { image in
                appState.setBaseImage(image, source: .camera)
            }
            .ignoresSafeArea()
        }
        .onChange(of: showCamera) { _, isShowing in
            guard let window = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .flatMap({ $0.windows })
                .first(where: { $0.isKeyWindow }),
                  let canvas = window.rootViewController?.view.viewWithTag(200) as? UIView else {
                return
            }

            if isShowing {
                // 🔥 Explicitly resign the canvas
                canvas.resignFirstResponder()
            } else {
                // 🔥 Bring it back so PKToolPicker reappears
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    canvas.becomeFirstResponder()
                }
            }
        }
    }
}

struct CameraPicker: UIViewControllerRepresentable {
    var onImagePicked: (UIImage) -> Void
    var onCancel: (() -> Void)? = nil

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImagePicked: onImagePicked, onCancel: onCancel)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImagePicked: (UIImage) -> Void
        let onCancel: (() -> Void)?

        init(onImagePicked: @escaping (UIImage) -> Void, onCancel: (() -> Void)?) {
            self.onImagePicked = onImagePicked
            self.onCancel = onCancel
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                onImagePicked(image)
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
            onCancel?()
        }
    }
}

struct ClearCanvasButton: View {
    let action: () -> Void

    var body: some View {
        Button {
            HapticManager.shared.lightTap()
            action()
        } label: {
            Image(systemName: "trash")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(
                    LinearGradient(
                        colors: [ColorPalette.error.opacity(0.9), ColorPalette.error.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(12)
                .shadow(color: ColorPalette.error.opacity(0.3), radius: 8, x: 0, y: 4)
        }
    }
}
