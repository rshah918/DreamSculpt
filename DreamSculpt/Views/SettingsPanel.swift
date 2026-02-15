//
//  SettingsPanel.swift
//  DreamSculpt
//

import SwiftUI

struct SettingsPanel: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                ColorPalette.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        generationSettingsSection
                        presetsSection
                        canvasAppearanceSection
                    }
                    .padding()
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        HapticManager.shared.lightTap()
                        dismiss()
                    }
                    .foregroundColor(ColorPalette.primary)
                }
            }
        }
    }

    private var generationSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Generation Settings")

            VStack(spacing: 20) {
                // Steps slider
                SettingsSlider(
                    title: "Steps",
                    value: Binding(
                        get: { Double(appState.generationSettings.steps) },
                        set: { appState.generationSettings.steps = Int($0) }
                    ),
                    range: 1...20,
                    step: 1,
                    description: "More steps = higher quality, slower generation"
                )

                // Denoising slider
                SettingsSlider(
                    title: "Denoising Strength",
                    value: $appState.generationSettings.denoisingStrength,
                    range: 0.3...1.0,
                    step: 0.05,
                    description: "Higher = more creative interpretation"
                )

                // CFG Scale slider
                SettingsSlider(
                    title: "CFG Scale",
                    value: $appState.generationSettings.cfgScale,
                    range: 1...20,
                    step: 0.5,
                    description: "Higher = follows prompt more closely"
                )
            }
            .padding()
            .glassmorphic(cornerRadius: 16)
        }
    }

    private var presetsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Quick Presets")

            HStack(spacing: 12) {
                PresetButton(
                    title: "Fast",
                    icon: "hare.fill",
                    isSelected: appState.generationSettings == .fast
                ) {
                    HapticManager.shared.lightTap()
                    appState.generationSettings = .fast
                }

                PresetButton(
                    title: "Balanced",
                    icon: "scale.3d",
                    isSelected: appState.generationSettings == .balanced
                ) {
                    HapticManager.shared.lightTap()
                    appState.generationSettings = .balanced
                }

                PresetButton(
                    title: "Quality",
                    icon: "star.fill",
                    isSelected: appState.generationSettings == .quality
                ) {
                    HapticManager.shared.lightTap()
                    appState.generationSettings = .quality
                }
            }
        }
    }

    private var canvasAppearanceSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Canvas Appearance")

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Paper Texture")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(ColorPalette.textPrimary)

                    Text("Adds subtle texture to canvas background")
                        .font(.caption)
                        .foregroundColor(ColorPalette.textMuted)
                }

                Spacer()

                Toggle("", isOn: $appState.showPaperTexture)
                    .tint(ColorPalette.primary)
                    .onChange(of: appState.showPaperTexture) { _, _ in
                        HapticManager.shared.lightTap()
                    }
            }
            .padding()
            .glassmorphic(cornerRadius: 16)
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundColor(ColorPalette.textPrimary)
    }
}

struct SettingsSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(ColorPalette.textPrimary)

                Spacer()

                Text(formattedValue)
                    .font(.subheadline.monospacedDigit())
                    .foregroundColor(ColorPalette.primary)
            }

            Slider(value: $value, in: range, step: step) { editing in
                if !editing {
                    HapticManager.shared.lightTap()
                }
            }
            .tint(ColorPalette.primary)

            Text(description)
                .font(.caption)
                .foregroundColor(ColorPalette.textMuted)
        }
    }

    private var formattedValue: String {
        if step >= 1 {
            return String(format: "%.0f", value)
        } else if step >= 0.1 {
            return String(format: "%.1f", value)
        } else {
            return String(format: "%.2f", value)
        }
    }
}

struct PresetButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 20))

                Text(title)
                    .font(.caption.weight(.medium))
            }
            .foregroundColor(isSelected ? .white : ColorPalette.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                Group {
                    if isSelected {
                        ColorPalette.gradientPrimary
                    } else {
                        Color.white.opacity(0.05)
                    }
                }
            )
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.clear : ColorPalette.glassBorder, lineWidth: 0.5)
            )
        }
    }
}

#Preview {
    SettingsPanel()
        .environmentObject(AppState())
}
