//
//  StorefrontView.swift
//  DreamSculpt
//

import SwiftUI
import StoreKit

struct StorefrontView: View {
    @ObservedObject var store = StoreManager.shared
    @Environment(\.dismiss) var dismiss
    @State private var selectedProduct: Product? = nil

    var body: some View {
        NavigationView {
            ZStack {
                ColorPalette.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        headerSection
                        currentBalanceSection
                        productsTable
                        buyButton
                        restoreButton
                    }
                    .padding()
                }
            }
            .navigationTitle("Get Generations")
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
            .alert("Purchase Failed", isPresented: .init(
                get: { store.purchaseError != nil },
                set: { if !$0 { store.purchaseError = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(store.purchaseError ?? "")
            }
            .onAppear {
                // Retry fetching if products haven't loaded
                if store.products.isEmpty {
                    Task { await store.fetchProducts() }
                }
                // Pre-select the middle option
                if selectedProduct == nil, store.products.count > 1 {
                    selectedProduct = store.products[1]
                }
            }
            .onChange(of: store.products) { _, products in
                if selectedProduct == nil, products.count > 1 {
                    selectedProduct = products[1]
                }
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 36))
                .foregroundStyle(ColorPalette.gradientPrimary)

            Text("More Generations")
                .font(.title2.weight(.bold))
                .foregroundColor(ColorPalette.textPrimary)

            Text("Transform your sketches into stunning AI images.")
                .font(.subheadline)
                .foregroundColor(ColorPalette.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    private var currentBalanceSection: some View {
        let manager = GenerationLimitManager.shared
        let credits = store.purchasedCredits
        let total = manager.freeGenerationsRemaining + credits

        return HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Your Balance")
                    .font(.caption)
                    .foregroundColor(ColorPalette.textMuted)
                HStack(spacing: 12) {
                    Label("\(manager.freeGenerationsRemaining) free today", systemImage: "clock")
                        .font(.caption.weight(.medium))
                        .foregroundColor(.green)
                    if credits > 0 {
                        Label("\(credits) purchased", systemImage: "star.fill")
                            .font(.caption.weight(.medium))
                            .foregroundColor(ColorPalette.primary)
                    }
                }
            }
            Spacer()
            Text("\(total)")
                .font(.system(size: 28, weight: .bold).monospacedDigit())
                .foregroundStyle(ColorPalette.gradientPrimary)
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(ColorPalette.glassBorder, lineWidth: 0.5)
        )
    }

    private var productsTable: some View {
        VStack(spacing: 0) {
            if store.products.isEmpty {
                VStack(spacing: 12) {
                    switch store.loadState {
                    case .failed(let message):
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.orange)
                        Text("Couldn't load store")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(ColorPalette.textPrimary)
                        Text(message)
                            .font(.caption)
                            .foregroundColor(ColorPalette.textMuted)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                        Button {
                            HapticManager.shared.lightTap()
                            Task { await store.fetchProducts() }
                        } label: {
                            Text("Retry")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 8)
                                .background(ColorPalette.gradientPrimary)
                                .cornerRadius(8)
                        }
                    default:
                        ProgressView()
                            .tint(ColorPalette.primary)
                        Text("Loading products...")
                            .font(.caption)
                            .foregroundColor(ColorPalette.textMuted)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                ForEach(Array(store.products.enumerated()), id: \.element.id) { index, product in
                    let count = StoreManager.generationCounts[product.id] ?? 0
                    let isSelected = selectedProduct?.id == product.id
                    let isBest = product.id == "com.DreamSculpt.generations.150"

                    Button {
                        HapticManager.shared.lightTap()
                        selectedProduct = product
                    } label: {
                        HStack(spacing: 14) {
                            // Selection indicator
                            ZStack {
                                Circle()
                                    .stroke(isSelected ? ColorPalette.primary : Color.white.opacity(0.3), lineWidth: 2)
                                    .frame(width: 22, height: 22)
                                if isSelected {
                                    Circle()
                                        .fill(ColorPalette.primary)
                                        .frame(width: 14, height: 14)
                                }
                            }

                            // Generation count + icon
                            Image(systemName: "sparkles")
                                .font(.system(size: 14))
                                .foregroundStyle(ColorPalette.gradientPrimary)

                            Text("\(count)")
                                .font(.system(size: 15, weight: .bold).monospacedDigit())
                                .foregroundColor(ColorPalette.textPrimary)

                            Text("generations")
                                .font(.subheadline)
                                .foregroundColor(ColorPalette.textSecondary)

                            Spacer()

                            // Badge
                            if isBest {
                                Text("Best Value!")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(ColorPalette.gradientPrimary)
                                    .cornerRadius(6)
                            }

                            // Price
                            Text(product.displayPrice)
                                .font(.system(size: 12, weight: .semibold).monospacedDigit())
                                .foregroundColor(ColorPalette.textPrimary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(isSelected ? ColorPalette.primary.opacity(0.1) : Color.clear)
                    }

                    // Divider between rows (not after last)
                    if index < store.products.count - 1 {
                        Divider()
                            .background(ColorPalette.glassBorder)
                            .padding(.leading, 52)
                    }
                }
            }
        }
        .background(Color.white.opacity(0.04))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(ColorPalette.glassBorder, lineWidth: 0.5)
        )
    }

    private var buyButton: some View {
        Button {
            guard let product = selectedProduct else { return }
            HapticManager.shared.mediumImpact()
            Task { await store.purchase(product) }
        } label: {
            Group {
                if store.purchaseInProgress {
                    ProgressView()
                        .tint(.white)
                } else if let product = selectedProduct {
                    Text("Purchase for \(product.displayPrice)")
                        .font(.headline)
                } else {
                    Text("Select a package")
                        .font(.headline)
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                selectedProduct != nil && !store.purchaseInProgress
                    ? ColorPalette.gradientPrimary
                    : LinearGradient(colors: [Color.gray.opacity(0.4), Color.gray.opacity(0.3)], startPoint: .leading, endPoint: .trailing)
            )
            .cornerRadius(14)
            .shadow(color: selectedProduct != nil ? ColorPalette.primary.opacity(0.3) : .clear, radius: 10, y: 4)
        }
        .disabled(selectedProduct == nil || store.purchaseInProgress)
    }

    private var restoreButton: some View {
        Button {
            Task {
                try? await AppStore.sync()
            }
        } label: {
            Text("Restore Purchases")
                .font(.caption)
                .foregroundColor(ColorPalette.textMuted)
        }
    }
}
