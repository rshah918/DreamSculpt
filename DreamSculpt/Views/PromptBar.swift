//
//  PromptBar.swift
//  DreamSculpt
//

import SwiftUI

struct PromptBar: View {
    @EnvironmentObject var appState: AppState
    @Binding var isExpanded: Bool
    @FocusState private var isTextFieldFocused: Bool
    @State private var editingPrompt: String = ""
    @State private var pulseAnimation: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            if isExpanded {
                expandedView
            } else {
                collapsedView
            }
        }
        .background(
            // Glow effect behind the bar
            RoundedRectangle(cornerRadius: 20)
                .fill(ColorPalette.primary.opacity(0.15))
                .blur(radius: 20)
                .scaleEffect(pulseAnimation ? 1.05 : 1.0)
        )
        .background(
            // Solid background
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.7))
        )
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [ColorPalette.primary.opacity(0.5), ColorPalette.accent.opacity(0.3), ColorPalette.primary.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: ColorPalette.primary.opacity(0.2), radius: 15, x: 0, y: 5)
        .padding(.horizontal, 16)
        .padding(.bottom, 140) // Extra padding to stay above tool picker
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isExpanded)
        .onChange(of: isExpanded) { _, expanded in
            if expanded {
                editingPrompt = appState.customPrompt
            }
        }
        .onAppear {
            // Subtle pulse animation for attention
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                pulseAnimation = true
            }
        }
    }

    private var collapsedView: some View {
        Button {
            HapticManager.shared.lightTap()
            isExpanded = true
        } label: {
            HStack(spacing: 12) {
                // Sparkle icon with gradient
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(ColorPalette.gradientPrimary)

                Text(appState.hasCustomPrompt ? truncatedPrompt : "Tap to customize your prompt...")
                    .font(.subheadline)
                    .foregroundColor(appState.hasCustomPrompt ? ColorPalette.textPrimary : ColorPalette.textSecondary)
                    .lineLimit(1)

                Spacer()

                // Chevron with hint
                HStack(spacing: 4) {
                    if !appState.hasCustomPrompt {
                        Text("Edit")
                            .font(.caption.weight(.medium))
                            .foregroundColor(ColorPalette.primary)
                    }
                    Image(systemName: "chevron.up.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(ColorPalette.gradientPrimary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
    }

    private var truncatedPrompt: String {
        let prompt = appState.customPrompt
        if prompt.count > 40 {
            return String(prompt.prefix(40)) + "..."
        }
        return prompt
    }

    private var expandedView: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Button {
                    HapticManager.shared.lightTap()
                    isTextFieldFocused = false
                    isExpanded = false
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(ColorPalette.textMuted)
                }

                Text("Custom Prompt")
                    .font(.headline)
                    .foregroundColor(ColorPalette.textPrimary)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            // Text editor
            TextEditor(text: $editingPrompt)
                .font(.subheadline)
                .foregroundColor(ColorPalette.textPrimary)
                .scrollContentBackground(.hidden)
                .frame(height: 80)
                .padding(12)
                .background(Color.white.opacity(0.05))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(ColorPalette.glassBorder, lineWidth: 0.5)
                )
                .padding(.horizontal, 16)
                .focused($isTextFieldFocused)

            // Style presets
            VStack(alignment: .leading, spacing: 8) {
                Text("Styles")
                    .font(.caption)
                    .foregroundColor(ColorPalette.textMuted)
                    .padding(.horizontal, 16)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(StylePreset.allCases) { preset in
                            StylePresetChip(
                                preset: preset,
                                isSelected: appState.selectedStylePreset == preset
                            ) {
                                HapticManager.shared.lightTap()
                                appState.applyStylePreset(preset)
                                editingPrompt = appState.customPrompt
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }

            // Action buttons
            HStack(spacing: 12) {
                Button {
                    HapticManager.shared.lightTap()
                    appState.resetPromptToDefault()
                    editingPrompt = appState.customPrompt
                } label: {
                    Text("Reset to Default")
                        .font(.subheadline)
                        .foregroundColor(ColorPalette.textSecondary)
                }

                Spacer()

                Button {
                    HapticManager.shared.mediumImpact()
                    appState.customPrompt = editingPrompt
                    isTextFieldFocused = false
                    isExpanded = false
                } label: {
                    HStack(spacing: 6) {
                        Text("Apply")
                            .font(.subheadline.weight(.semibold))
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(ColorPalette.gradientPrimary)
                    .cornerRadius(10)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }
}

struct StylePresetChip: View {
    let preset: StylePreset
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: preset.icon)
                    .font(.system(size: 12))
                Text(preset.rawValue)
                    .font(.caption.weight(.medium))
            }
            .foregroundColor(isSelected ? .white : ColorPalette.textSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Group {
                    if isSelected {
                        ColorPalette.gradientPrimary
                    } else {
                        Color.white.opacity(0.08)
                    }
                }
            )
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? Color.clear : ColorPalette.glassBorder, lineWidth: 0.5)
            )
        }
    }
}

#Preview {
    ZStack {
        ColorPalette.background
            .ignoresSafeArea()

        VStack {
            Spacer()
            PromptBar(isExpanded: .constant(true))
        }
    }
    .environmentObject(AppState())
}
