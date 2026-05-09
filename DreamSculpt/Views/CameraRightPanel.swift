//
//  CameraRightPanel.swift
//  DreamSculpt
//

import SwiftUI
import Photos
import PhotosUI

struct CameraRightPanel: View {
    var showCamera: Bool
    var onImagePicked: (UIImage, BaseImageSource) -> Void

    @State private var assets: [PHAsset] = []
    @State private var photosLoaded = false
    @State private var showNativeCamera = false
    @State private var cameraReady = false
    @State private var dummyCapture = false
    @State private var dummyFlip = false
    @State private var dummyZoom: CGFloat = 1.0

    // Seam grabber state
    @State private var photoSelection: PhotosPickerItem? = nil
    @State private var showPhotosPicker: Bool = false
    @State private var grabberDragOffset: CGFloat = 0

    private let grabberH: CGFloat = 22

    var body: some View {
        GeometryReader { geo in
            // Live-resize the seam during a vertical drag on the grabber.
            // Positive grabberDragOffset (swipe down) → viewfinder grows.
            // Negative grabberDragOffset (swipe up)   → photo grid grows.
            let totalH = geo.size.height
            let baseViewfinderH = totalH * 0.55
            let basePhotoH = totalH * 0.45 - grabberH
            let minPane: CGFloat = 80
            let maxAdj = basePhotoH - minPane
            let minAdj = minPane - baseViewfinderH
            let dragAdj = max(minAdj, min(maxAdj, grabberDragOffset))
            // Round to whole pixels — eliminates subpixel layout jitter on the grabber strip.
            let viewfinderH = (baseViewfinderH + dragAdj).rounded()
            let photoH = (basePhotoH - dragAdj).rounded()
            // Cell size is fixed at the baseline so thumbnails don't resize during drag
            // (which caused the LazyHGrid to relayout every frame, jittering the photos).
            let cs = min(120, (basePhotoH - 6 - 24) / 2).rounded()

            ZStack(alignment: .top) {
                // Teaser extends 18pt past the viewfinder seam so the drawer's
                // rounded top corners cut into teaser pixels (not the canvas
                // behind the panel) during the CTA pulse.
                teaserLayer
                    .frame(maxWidth: .infinity)
                    .frame(height: viewfinderH + 18)
                    .opacity(cameraReady ? 0 : 1)
                    .animation(.easeInOut(duration: 1.0), value: cameraReady)
                    .allowsHitTesting(false)

                VStack(spacing: 0) {
                    // Live viewfinder — resizes with grabber drag
                    ZStack {
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
                    .frame(height: viewfinderH)

                    // Photo library "drawer": grabber + grid share one rounded, lifted container
                    VStack(spacing: 0) {
                        // Seam grabber — pull up = full PhotosPicker, pull down = native camera
                        seamGrabber

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
                    }
                    .background(Color(white: 0.10))
                    .clipShape(RoundedCorner(radius: 18, corners: [.topLeft, .topRight]))
                    .shadow(color: .black.opacity(0.7), radius: 12, y: -6)
                }

                CameraPickerHost(
                    isPresented: $showNativeCamera,
                    onImagePicked: { image in
                        showNativeCamera = false
                        onImagePicked(image, .camera)
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
        .photosPicker(isPresented: $showPhotosPicker, selection: $photoSelection, matching: .images)
        .onChange(of: photoSelection) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let img = UIImage(data: data) {
                    await MainActor.run { onImagePicked(img, .library) }
                }
                await MainActor.run { photoSelection = nil }
            }
        }
    }

    // MARK: - Seam grabber

    private var seamGrabber: some View {
        // Capsule centered in a strip that fills the parent width. The strip itself
        // moves with the seam during drag (the viewfinder/photo heights are recomputed
        // from grabberDragOffset), so the gesture uses .global to avoid feedback from
        // the moving local coordinate space.
        Capsule()
            .fill(Color.white.opacity(0.55))
            .frame(width: 36, height: 5)
            .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
            .frame(maxWidth: .infinity)
            .frame(height: grabberH)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 5, coordinateSpace: .global)
                    .onChanged { value in
                        grabberDragOffset = value.translation.height
                    }
                    .onEnded { value in
                        let threshold: CGFloat = 50
                        if value.translation.height < -threshold {
                            HapticManager.shared.lightTap()
                            showPhotosPicker = true
                        } else if value.translation.height > threshold {
                            HapticManager.shared.lightTap()
                            showNativeCamera = true
                        }
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                            grabberDragOffset = 0
                        }
                    }
            )
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
                .scaleEffect(1.18)
        }
        .clipped()
        // Rasterise the gradient+image composite so re-clipping during the slide-in
        // animation is cheap (single GPU blit) instead of recomposing every frame.
        .drawingGroup()
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
                DispatchQueue.main.async { onImagePicked(image, .library) }
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
