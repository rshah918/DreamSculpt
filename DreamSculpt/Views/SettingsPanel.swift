//
//  SettingsPanel.swift
//  DreamSculpt
//

import SwiftUI

struct SettingsPanel: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @State private var showStorefront = false

    var body: some View {
        NavigationView {
            ZStack {
                ColorPalette.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        generationLimitSection
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
        .sheet(isPresented: $showStorefront) {
            StorefrontView()
        }
    }

    private var generationLimitSection: some View {
        let manager = GenerationLimitManager.shared
        let used = manager.generationsUsedToday
        let remaining = manager.generationsRemaining

        let limitColor: Color = {
            switch remaining {
            case 7...10000: return .green
            case 4...6: return .yellow
            case 1...3: return .orange
            default: return ColorPalette.error
            }
        }()

        return VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Daily Generations")

            VStack(spacing: 12) {
                HStack {
                    Circle()
                        .fill(limitColor)
                        .frame(width: 8, height: 8)

                    Text("\(remaining) remaining")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(limitColor)

                    Spacer()

                    Text("\(used) / 10 free used")
                        .font(.caption)
                        .foregroundColor(ColorPalette.textMuted)
                }

                ProgressView(value: Double(min(used, 10)), total: 10)
                    .tint(limitColor)

                if manager.purchasedCredits > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundColor(ColorPalette.primary)
                        Text("\(manager.purchasedCredits) purchased credits")
                            .font(.caption.weight(.medium))
                            .foregroundColor(ColorPalette.primary)
                        Spacer()
                    }
                }

                Button {
                    HapticManager.shared.mediumImpact()
                    showStorefront = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "cart.fill")
                            .font(.system(size: 14))
                        Text("Buy More Generations")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(ColorPalette.gradientPrimary)
                    .cornerRadius(12)
                }

                #if DEBUG
                Button {
                    GenerationLimitManager.shared.resetCount()
                    appState.refreshGenerationCount()
                    StoreManager.shared.purchasedCredits = 0
                    HapticManager.shared.lightTap()
                } label: {
                    Text("Reset Count (Debug)")
                        .font(.caption)
                        .foregroundColor(ColorPalette.textMuted)
                }
                #endif
            }
            .padding(16)
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(ColorPalette.glassBorder, lineWidth: 0.5)
            )
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundColor(ColorPalette.textPrimary)
    }
}

#Preview {
    SettingsPanel()
        .environmentObject(AppState())
}
