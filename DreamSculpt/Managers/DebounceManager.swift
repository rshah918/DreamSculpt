//
//  DebounceManager.swift
//  DreamSculpt
//

import Foundation

class DebounceManager {
    static let shared = DebounceManager()

    private var lastRequestTime: Date = .distantPast
    private var isStrokeInProgress = false
    private let minInterval: TimeInterval

    init(minInterval: TimeInterval = 5.0) {
        self.minInterval = minInterval
    }

    func shouldAllowRequest() -> Bool {
        let now = Date()
        guard !isStrokeInProgress else { return false }
        guard now.timeIntervalSince(lastRequestTime) >= minInterval else { return false }
        lastRequestTime = now
        return true
    }

    func strokeBegan() {
        isStrokeInProgress = true
    }

    func strokeEnded() {
        isStrokeInProgress = false
    }

    func reset() {
        lastRequestTime = .distantPast
        isStrokeInProgress = false
    }
}
