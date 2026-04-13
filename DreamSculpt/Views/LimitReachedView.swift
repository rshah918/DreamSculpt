//
//  LimitReachedView.swift
//  DreamSculpt
//

import SwiftUI

struct LimitReachedView: View {
    @Binding var isPresented: Bool
    @State private var showStorefront = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation { isPresented = false }
                }

            VStack(spacing: 24) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.orange, .red],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                Text("Daily Limit Reached")
                    .font(.title2.weight(.bold))
                    .foregroundColor(ColorPalette.textPrimary)

                Text("You've used all 10 free generations for today.\nBuy more or come back tomorrow!")
                    .font(.subheadline)
                    .foregroundColor(ColorPalette.textSecondary)
                    .multilineTextAlignment(.center)

                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.system(size: 13))
                    let time = GenerationLimitManager.shared.timeUntilReset
                    Text("Resets in \(time.hours)h \(time.minutes)m")
                        .font(.caption.weight(.medium))
                }
                .foregroundColor(ColorPalette.textMuted)

                VStack(spacing: 12) {
                    Button {
                        HapticManager.shared.mediumImpact()
                        showStorefront = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "cart.fill")
                                .font(.system(size: 14))
                            Text("Buy More Generations")
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(ColorPalette.gradientPrimary)
                        .cornerRadius(12)
                    }

                    Button {
                        HapticManager.shared.lightTap()
                        withAnimation { isPresented = false }
                    } label: {
                        Text("Dismiss")
                            .font(.subheadline)
                            .foregroundColor(ColorPalette.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                }
            }
            .padding(32)
            .background(ColorPalette.background)
            .glassmorphic(cornerRadius: 24)
            .padding(.horizontal, 32)
        }
        .sheet(isPresented: $showStorefront) {
            StorefrontView()
        }
    }
}
