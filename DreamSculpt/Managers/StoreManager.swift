//
//  StoreManager.swift
//  DreamSculpt
//

import StoreKit

@MainActor
class StoreManager: ObservableObject {
    static let shared = StoreManager()

    @Published var products: [Product] = []
    @Published var purchaseInProgress = false
    @Published var purchaseError: String? = nil
    @Published var purchasedCredits: Int = GenerationLimitManager.shared.purchasedCredits

    var onPurchaseComplete: (() -> Void)?

    static let productIDs: [String] = [
        "com.DreamSculpt.generations.10",
        "com.DreamSculpt.generations.50",
        "com.DreamSculpt.generations.150"
    ]

    static let generationCounts: [String: Int] = [
        "com.DreamSculpt.generations.10": 10,
        "com.DreamSculpt.generations.50": 50,
        "com.DreamSculpt.generations.150": 150
    ]

    private init() {
        Task { await fetchProducts() }
        observeTransactions()
    }

    func fetchProducts() async {
        do {
            let storeProducts = try await Product.products(for: Self.productIDs)
            products = storeProducts.sorted { $0.price < $1.price }
        } catch {
            print("Failed to fetch products: \(error)")
        }
    }

    func purchase(_ product: Product) async {
        purchaseInProgress = true
        purchaseError = nil

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                do {
                    let transaction = try checkVerified(verification)
                    if let count = Self.generationCounts[product.id] {
                        GenerationLimitManager.shared.addPurchasedCredits(count)
                        purchasedCredits = GenerationLimitManager.shared.purchasedCredits
                        onPurchaseComplete?()
                    }
                    await transaction.finish()
                } catch {
                    // Verification failed — still finish the transaction to avoid it being stuck
                    if case .success(let innerResult) = result,
                       let transaction = try? innerResult.payloadValue {
                        await transaction.finish()
                    }
                    purchaseError = "Purchase verification failed."
                }
                purchaseInProgress = false

            case .userCancelled:
                purchaseInProgress = false

            case .pending:
                purchaseInProgress = false

            @unknown default:
                purchaseInProgress = false
            }
        } catch {
            purchaseError = error.localizedDescription
            purchaseInProgress = false
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }

    private func observeTransactions() {
        Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try await self.checkVerified(result)
                    if let count = Self.generationCounts[transaction.productID] {
                        await MainActor.run {
                            GenerationLimitManager.shared.addPurchasedCredits(count)
                            self.purchasedCredits = GenerationLimitManager.shared.purchasedCredits
                            self.onPurchaseComplete?()
                        }
                    }
                    await transaction.finish()
                } catch {
                    print("Unverified transaction update: \(error)")
                }
            }
        }
    }
}
