//
//  CameraRightPanel.swift
//  DreamSculpt
//

import SwiftUI
import Photos

struct CameraRightPanel: View {
    var showCamera: Bool
    var onImagePicked: (UIImage) -> Void

    @State private var assets: [PHAsset] = []
    @State private var photosLoaded = false
    @State private var showNativeCamera = false
    @State private var cameraReady = false
    @State private var dummyCapture = false
    @State private var dummyFlip = false
    @State private var dummyZoom: CGFloat = 1.0

    var body: some View {
        GeometryReader { geo in
            // Cell size fills the photo area exactly: 45% height, 2 rows, spacing + padding
            let photoH = geo.size.height * 0.45
            let cs = min(120, (photoH - 6 - 24) / 2)

            ZStack {
                VStack(spacing: 0) {
                    // Live viewfinder — top 55%
                    ZStack {
                        teaserLayer
                            .opacity(cameraReady ? 0 : 1)
                            .animation(.easeInOut(duration: 1.0), value: cameraReady)

                        if showCamera {
                            CameraLiveView(
                                onCapture: { _ in },
                                onCameraReady: { cameraReady = true },
                                triggerCapture: $dummyCapture,
                                triggerFlip: $dummyFlip,
                                zoomFactor: $dummyZoom
                            )
                        }

                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture {
                                HapticManager.shared.lightTap()
                                showNativeCamera = true
                            }

                        // Gradient fade at bottom — reinforces "viewfinder is behind"
                        LinearGradient(
                            colors: [.clear, Color(white: 0.10)],
                            startPoint: .init(x: 0.5, y: 0.6),
                            endPoint: .bottom
                        )
                        .allowsHitTesting(false)

                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Label("Tap to capture", systemImage: "camera.viewfinder")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white.opacity(0.55))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Capsule().fill(Color.black.opacity(0.35)))
                                    .padding([.trailing, .bottom], 14)
                            }
                        }
                        .allowsHitTesting(false)
                    }
                    .frame(height: geo.size.height * 0.55)

                    // Photo library — rounded top corners + upward shadow to sit "on top"
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHGrid(
                            rows: [GridItem(.fixed(cs)), GridItem(.fixed(cs))],
                            spacing: 6
                        ) {
                            ForEach(assets.indices, id: \.self) { idx in
                                Button {
                                    HapticManager.shared.lightTap()
                                    fetchFullRes(assets[idx])
                                } label: {
                                    PhotoThumbnailView(asset: assets[idx], size: cs)
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                    }
                    .frame(height: photoH)
                    .background(Color(white: 0.10))
                    .clipShape(RoundedCorner(radius: 18, corners: [.topLeft, .topRight]))
                    .shadow(color: .black.opacity(0.7), radius: 12, y: -6)
                }

                CameraPickerHost(
                    isPresented: $showNativeCamera,
                    onImagePicked: { image in
                        showNativeCamera = false
                        onImagePicked(image)
                    },
                    onCancel: { showNativeCamera = false }
                )
                .allowsHitTesting(false)
                .frame(width: 0, height: 0)
            }
        }
        .onChange(of: showCamera) { _, isOpen in
            if isOpen && !photosLoaded {
                photosLoaded = true
                fetchAssets()
            }
            if !isOpen {
                cameraReady = false
                showNativeCamera = false
                dummyZoom = 1.0
            }
        }
    }

    // MARK: - Teaser

    private var teaserLayer: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "1a0533"), Color(hex: "0d1f3c"), Color(hex: "2d1500")],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            Image("cyberpunk_teaser")
                .resizable()
                .scaledToFill()
        }
        .clipped()
    }

    // MARK: - Fetch assets

    private func fetchAssets() {
        DispatchQueue.global(qos: .userInitiated).async {
            let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
            if status == .notDetermined {
                PHPhotoLibrary.requestAuthorization(for: .readWrite) { s in
                    if s == .authorized || s == .limited { loadAssets() }
                }
            } else if status == .authorized || status == .limited {
                loadAssets()
            }
        }
    }

    private func loadAssets() {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.fetchLimit = 30
        let results = PHAsset.fetchAssets(with: .image, options: options)
        var loaded: [PHAsset] = []
        results.enumerateObjects { asset, _, _ in loaded.append(asset) }
        DispatchQueue.main.async { assets = loaded }
    }

    private func fetchFullRes(_ asset: PHAsset) {
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        manager.requestImage(
            for: asset,
            targetSize: PHImageManagerMaximumSize,
            contentMode: .aspectFit,
            options: options
        ) { image, _ in
            if let image {
                DispatchQueue.main.async { onImagePicked(image) }
            }
        }
    }
}

// MARK: - Thumbnail cell

private struct PhotoThumbnailView: View {
    let asset: PHAsset
    let size: CGFloat
    @State private var thumbnail: UIImage?

    var body: some View {
        ZStack {
            Color(white: 0.10)
            if let thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFill()
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .onAppear(perform: load)
    }

    private func load() {
        guard thumbnail == nil else { return }
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.isNetworkAccessAllowed = true
        manager.requestImage(
            for: asset,
            targetSize: CGSize(width: 180, height: 180),
            contentMode: .aspectFill,
            options: options
        ) { image, _ in
            if let image { DispatchQueue.main.async { thumbnail = image } }
        }
    }
}

// MARK: - Camera picker host

private struct CameraPickerHost: UIViewRepresentable {
    @Binding var isPresented: Bool
    var onImagePicked: (UIImage) -> Void
    var onCancel: () -> Void

    func makeUIView(context: Context) -> UIView {
        let v = UIView()
        v.isUserInteractionEnabled = false
        return v
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if isPresented && context.coordinator.activePicker == nil {
            let picker = UIImagePickerController()
            picker.sourceType = .camera
            picker.delegate = context.coordinator
            picker.modalPresentationStyle = .overFullScreen
            picker.modalTransitionStyle = .crossDissolve
            context.coordinator.activePicker = picker
            DispatchQueue.main.async {
                uiView.window?.rootViewController?.present(picker, animated: true)
            }
        } else if !isPresented, let picker = context.coordinator.activePicker {
            picker.dismiss(animated: false)
            context.coordinator.activePicker = nil
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(isPresented: $isPresented, onImagePicked: onImagePicked, onCancel: onCancel)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        @Binding var isPresented: Bool
        var onImagePicked: (UIImage) -> Void
        var onCancel: () -> Void
        weak var activePicker: UIImagePickerController?

        init(isPresented: Binding<Bool>, onImagePicked: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
            _isPresented = isPresented
            self.onImagePicked = onImagePicked
            self.onCancel = onCancel
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            activePicker = nil
            if let image = info[.originalImage] as? UIImage { onImagePicked(image) }
            picker.dismiss(animated: false)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            activePicker = nil
            picker.dismiss(animated: false)
            onCancel()
        }
    }
}
