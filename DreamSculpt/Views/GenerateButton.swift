//
//  GenerateButton.swift
//  DreamSculpt
//
//  Generate button for triggering AI image generation

import SwiftUI

struct GenerateButton: View {
    @EnvironmentObject var appState: AppState
    var hasDrawing: Bool
    var hasBaseImage: Bool = false
    var onTrigger: () -> Void

    private var isDisabled: Bool {
        appState.isLoading || (!hasDrawing && !hasBaseImage)
    }

    var body: some View {
        Button(action: {
            HapticManager.shared.mediumImpact()
            onTrigger()
        }) {
            HStack(spacing: 6) {
                if appState.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.7)
                } else {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14, weight: .semibold))
                }

                Text("Generate")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                LinearGradient(
                    colors: [
                        ColorPalette.primary.opacity(isDisabled ? 0.4 : 0.9),
                        ColorPalette.accent.opacity(isDisabled ? 0.4 : 0.9)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(10)
            .shadow(color: ColorPalette.primary.opacity(isDisabled ? 0.1 : 0.3), radius: 8, x: 0, y: 4)
        }
        .disabled(isDisabled)
    }
}
