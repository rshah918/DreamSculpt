//
//  GenerateButton.swift
//  DreamSculpt
//
//  Generate button for triggering AI image generation

import SwiftUI

struct GenerateButton: View {
    enum Size {
        case compact   // small button next to the prompt bar
        case large     // wide button at the bottom of the expanded prompt sheet
    }

    @EnvironmentObject var appState: AppState
    var hasDrawing: Bool
    var hasBaseImage: Bool = false
    var size: Size = .compact
    var onTrigger: () -> Void

    /// Disabled only while a generation is already in flight. No other
    /// gating — empty canvas, repeat input, etc. all still fire.
    private var isDisabled: Bool {
        appState.isLoading
    }

    private var iconSize: CGFloat { size == .large ? 14 : 12 }
    private var textSize: CGFloat { size == .large ? 14 : 12 }
    private var hPad: CGFloat { size == .large ? 20 : 12 }
    private var vPad: CGFloat { size == .large ? 10 : 7 }

    var body: some View {
        Button(action: {
            HapticManager.shared.mediumImpact()
            onTrigger()
        }) {
            HStack(spacing: 5) {
                if appState.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(size == .large ? 0.8 : 0.6)
                } else {
                    Image(systemName: "sparkles")
                        .font(.system(size: iconSize, weight: .semibold))
                }

                Text("Generate")
                    .font(.system(size: textSize, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, hPad)
            .padding(.vertical, vPad)
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
