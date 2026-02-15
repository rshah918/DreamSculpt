//
//  HapticManager.swift
//  DreamSculpt
//

import UIKit

final class HapticManager {
    static let shared = HapticManager()

    private let lightGenerator = UIImpactFeedbackGenerator(style: .light)
    private let mediumGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let heavyGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private let notificationGenerator = UINotificationFeedbackGenerator()
    private let selectionGenerator = UISelectionFeedbackGenerator()

    private init() {
        prepareGenerators()
    }

    private func prepareGenerators() {
        lightGenerator.prepare()
        mediumGenerator.prepare()
        heavyGenerator.prepare()
        notificationGenerator.prepare()
        selectionGenerator.prepare()
    }

    func lightTap() {
        lightGenerator.impactOccurred()
        lightGenerator.prepare()
    }

    func mediumImpact() {
        mediumGenerator.impactOccurred()
        mediumGenerator.prepare()
    }

    func heavyImpact() {
        heavyGenerator.impactOccurred()
        heavyGenerator.prepare()
    }

    func success() {
        notificationGenerator.notificationOccurred(.success)
        notificationGenerator.prepare()
    }

    func warning() {
        notificationGenerator.notificationOccurred(.warning)
        notificationGenerator.prepare()
    }

    func error() {
        notificationGenerator.notificationOccurred(.error)
        notificationGenerator.prepare()
    }

    func selection() {
        selectionGenerator.selectionChanged()
        selectionGenerator.prepare()
    }

    func generationStarted() {
        mediumImpact()
    }

    func generationCompleted() {
        success()
    }

    func generationFailed() {
        error()
    }
}
