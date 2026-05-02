//
//  BasePhotoControlBar.swift
//  DreamSculpt
//

import SwiftUI

struct BasePhotoControlBar: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "photo.fill")
                    .font(.system(size: 12, weight: .medium))
                Text("Base photo")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [ColorPalette.accent, ColorPalette.primary],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )

            Spacer()

            Button {
                HapticManager.shared.lightTap()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    appState.setBaseImage(nil)
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                    Text("Remove")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Capsule().fill(Color.red.opacity(0.72)))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.black.opacity(0.55))
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(.ultraThinMaterial)
                )
        )
        .shadow(color: ColorPalette.primary.opacity(0.18), radius: 8)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
