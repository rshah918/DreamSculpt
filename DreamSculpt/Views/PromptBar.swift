//
//  PromptBar.swift
//  DreamSculpt
//

import SwiftUI
import Combine

struct PromptBar: View {
    @EnvironmentObject var appState: AppState
    @Binding var isExpanded: Bool
    @FocusState private var isTextFieldFocused: Bool
    @State private var editingPrompt: String = ""
    @State private var pulseAnimation: Bool = false
    
    // Track keyboard height for automatic push-up
    @State private var keyboardHeight: CGFloat = 0
    
    var hasDrawing: Bool = false
    var hasBaseImage: Bool = false
    var onGenerate: () -> Void = {}
    var onCollapse: () -> Void = {}
    var onUndo: () -> Void = {}

    var body: some View {
        VStack(spacing: 12) {
            // Action buttons above the prompt bar
            if !isExpanded {
                HStack(spacing: 12) {
                    Spacer()

                    // Undo button
                    Button {
                        HapticManager.shared.lightTap()
                        onUndo()
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                    }

                    GenerateButton(hasDrawing: hasDrawing, hasBaseImage: hasBaseImage, onTrigger: onGenerate)
                }
            }

            // Prompt bar
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
        }
        .padding(.horizontal, 16)
        // Dynamically adds keyboard height so the bar moves up
        .padding(.bottom, 140 + keyboardHeight)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isExpanded)
        .animation(.easeOut(duration: 0.25), value: keyboardHeight)
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
        // Keyboard handling (fixed the conditional binding error)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
            if let keyboardFrame = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
                keyboardHeight = keyboardFrame.height
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardHeight = 0
        }
    }

    private var collapsedView: some View {
        Button {
            HapticManager.shared.lightTap()
            isExpanded = true
        } label: {
            HStack(spacing: 10) {
                // Sparkle icon with gradient
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(ColorPalette.gradientPrimary)

                Text(appState.hasCustomPrompt ? truncatedPrompt : "Tap to customize prompt...")
                    .font(.caption)
                    .foregroundColor(appState.hasCustomPrompt ? ColorPalette.textPrimary : ColorPalette.textSecondary)
                    .lineLimit(1)

                Spacer()

                // Chevron with hint
                HStack(spacing: 4) {
                    if !appState.hasCustomPrompt {
                        Text("Edit")
                            .font(.caption2.weight(.medium))
                            .foregroundColor(ColorPalette.primary)
                    }
                    Image(systemName: "chevron.up.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(ColorPalette.gradientPrimary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
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
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(ColorPalette.textMuted)

                Text("Custom Prompt")
                    .font(.headline)
                    .foregroundColor(ColorPalette.textPrimary)

                Spacer()
            }
            .contentShape(Rectangle())
            .onTapGesture {
                HapticManager.shared.lightTap()
                isTextFieldFocused = false
                isExpanded = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    onCollapse()
                }
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

                ScrollView(.horizontal, showsIndicators: false){
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
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        onCollapse()
                    }
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
