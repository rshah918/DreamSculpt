//
//  AppState.swift
//  DreamSculpt
//

import SwiftUI
import Combine

@MainActor
class AppState: ObservableObject {
    @Published var currentPreviewImage: UIImage? = nil
    @Published var isDrawerOpen: Bool = false
    @Published var isLoading: Bool = false
    @Published var history: [GenerationRecord] = []
    @Published var baseImage: UIImage? = nil

    // Session history - in-memory list of all generations this session
    @Published var sessionImages: [UIImage] = []
    @Published var sessionIndex: Int = 0

    // Prompt customization
    @Published var customPrompt: String {
        didSet { savePrompt() }
    }
    @Published var showPromptBar: Bool = false
    @Published var selectedStylePreset: StylePreset? = nil

    // Generation settings
    @Published var generationSettings: GenerationSettings {
        didSet { saveSettings() }
    }

    // Canvas appearance
    @Published var showPaperTexture: Bool {
        didSet { UserDefaults.standard.set(showPaperTexture, forKey: "showPaperTexture") }
    }

    static let defaultPrompt = """
    Transform this rough sketch into an awe-inspiring, photorealistic image. Use the sketch only as a structural guide for composition and proportions. Add realistic depth, dramatic lighting, and atmospheric effects such as reflections, sky, and shadows, so the scene feels immersive and cinematic. The final result should look like a stunning photograph, true to the layout of the sketch but elevated into a vivid, breathtaking real-world scene
    """

    // Track if we've had at least one generation
    var hasGeneratedImage: Bool {
        !sessionImages.isEmpty
    }

    var hasCustomPrompt: Bool {
        customPrompt != Self.defaultPrompt
    }

    init() {
        // Load persisted values
        customPrompt = UserDefaults.standard.string(forKey: "customPrompt") ?? Self.defaultPrompt
        showPaperTexture = UserDefaults.standard.object(forKey: "showPaperTexture") as? Bool ?? true

        if let settingsData = UserDefaults.standard.data(forKey: "generationSettings"),
           let settings = try? JSONDecoder().decode(GenerationSettings.self, from: settingsData) {
            generationSettings = settings
        } else {
            generationSettings = .default
        }

        loadHistory()
    }

    private func savePrompt() {
        UserDefaults.standard.set(customPrompt, forKey: "customPrompt")
    }

    private func saveSettings() {
        if let data = try? JSONEncoder().encode(generationSettings) {
            UserDefaults.standard.set(data, forKey: "generationSettings")
        }
    }

    func resetPromptToDefault() {
        customPrompt = Self.defaultPrompt
        selectedStylePreset = nil
    }

    func applyStylePreset(_ preset: StylePreset) {
        selectedStylePreset = preset
        customPrompt = "Transform this sketch into: \(preset.promptSnippet)"
    }

    func loadHistory() {
        history = HistoryManager.shared.loadHistory()
    }

    func addToHistory(sketch: UIImage, result: UIImage) {
        // Add to session history
        sessionImages.append(result)
        sessionIndex = sessionImages.count - 1

        // Persist to disk
        if let record = HistoryManager.shared.saveGeneration(sketch: sketch, result: result) {
            history.insert(record, at: 0)
        }
    }

    func deleteFromHistory(_ record: GenerationRecord) {
        HistoryManager.shared.deleteGeneration(record)
        history.removeAll { $0.id == record.id }
    }

    func toggleDrawer() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            isDrawerOpen.toggle()
        }
    }

    func setBaseImage(_ image: UIImage?) {
        baseImage = image
    }

    func setSessionIndex(_ index: Int) {
        guard index >= 0 && index < sessionImages.count else { return }
        sessionIndex = index
        currentPreviewImage = sessionImages[index]
    }
}
