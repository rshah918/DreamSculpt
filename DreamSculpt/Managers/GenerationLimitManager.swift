//
//  GenerationLimitManager.swift
//  DreamSculpt
//

import Foundation

class GenerationLimitManager {
    static let shared = GenerationLimitManager()

    private let dailyLimit = 10
    private let countKey = "generationCount"
    private let dateKey = "generationDate"

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

    var generationsUsedToday: Int {
        resetIfNewDay()
        return UserDefaults.standard.integer(forKey: countKey)
    }

    var generationsRemaining: Int {
        max(0, dailyLimit - generationsUsedToday)
    }

    func canGenerate() -> Bool {
        generationsUsedToday < dailyLimit
    }

    func incrementCount() {
        resetIfNewDay()
        let current = UserDefaults.standard.integer(forKey: countKey)
        UserDefaults.standard.set(current + 1, forKey: countKey)
    }

    #if DEBUG
    func resetCount() {
        UserDefaults.standard.set(0, forKey: countKey)
        UserDefaults.standard.set(todayString, forKey: dateKey)
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
