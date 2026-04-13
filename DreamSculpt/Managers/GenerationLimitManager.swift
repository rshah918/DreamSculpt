//
//  GenerationLimitManager.swift
//  DreamSculpt
//

import Foundation
import Security

class GenerationLimitManager {
    static let shared = GenerationLimitManager()

    private let dailyFreeLimit = 3
    private let countKey = "generationCount"
    private let dateKey = "generationDate"
    private let keychainAccount = "com.DreamSculpt.purchasedCredits"

    private init() {}

    private var todayString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    private func resetIfNewDay() {
        let storedDate = UserDefaults.standard.string(forKey: dateKey) ?? ""
        if storedDate != todayString {
            UserDefaults.standard.set(0, forKey: countKey)
            UserDefaults.standard.set(todayString, forKey: dateKey)
        }
    }

    // MARK: - Free daily generations

    var generationsUsedToday: Int {
        resetIfNewDay()
        return UserDefaults.standard.integer(forKey: countKey)
    }

    var freeGenerationsRemaining: Int {
        max(0, dailyFreeLimit - generationsUsedToday)
    }

    // MARK: - Purchased credits (Keychain-backed)

    var purchasedCredits: Int {
        readKeychainCredits()
    }

    func addPurchasedCredits(_ count: Int) {
        let current = readKeychainCredits()
        writeKeychainCredits(current + count)
    }

    private func usePurchasedCredit() {
        let current = readKeychainCredits()
        if current > 0 {
            writeKeychainCredits(current - 1)
        }
    }

    private func readKeychainCredits() -> Int {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8),
              let value = Int(string) else {
            return 0
        }
        return value
    }

    private func writeKeychainCredits(_ value: Int) {
        let data = String(value).data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainAccount
        ]
        // Try to update existing
        let updateAttributes: [String: Any] = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(query as CFDictionary, updateAttributes as CFDictionary)
        if updateStatus == errSecItemNotFound {
            // Create new
            var newItem = query
            newItem[kSecValueData as String] = data
            SecItemAdd(newItem as CFDictionary, nil)
        }
    }

    // MARK: - Combined logic

    var generationsRemaining: Int {
        freeGenerationsRemaining + purchasedCredits
    }

    func canGenerate() -> Bool {
        freeGenerationsRemaining > 0 || purchasedCredits > 0
    }

    func incrementCount() {
        resetIfNewDay()
        if freeGenerationsRemaining > 0 {
            let current = UserDefaults.standard.integer(forKey: countKey)
            UserDefaults.standard.set(current + 1, forKey: countKey)
        } else {
            usePurchasedCredit()
        }
    }

    #if DEBUG
    func resetCount() {
        UserDefaults.standard.set(0, forKey: countKey)
        UserDefaults.standard.set(todayString, forKey: dateKey)
        writeKeychainCredits(0)
    }
    #endif

    var timeUntilReset: (hours: Int, minutes: Int) {
        let calendar = Calendar.current
        let now = Date()
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) else {
            return (0, 0)
        }
        let components = calendar.dateComponents([.hour, .minute], from: now, to: tomorrow)
        return (hours: components.hour ?? 0, minutes: components.minute ?? 0)
    }
}
