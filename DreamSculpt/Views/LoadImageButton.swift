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
                        appState.setBaseImage(image)
                    }
                }
            }
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
