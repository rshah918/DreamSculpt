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
    @Published var sessionId: String = UUID().uuidString

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

    // Generation limit
    @Published var showLimitReachedOverlay: Bool = false
    @Published var generationsRemaining: Int = GenerationLimitManager.shared.generationsRemaining

    func refreshGenerationCount() {
        generationsRemaining = GenerationLimitManager.shared.generationsRemaining
    }

    static let defaultPrompt = """
    Transform this rough sketch into an awe-inspiring, photorealistic image. Use the sketch only as a structural guide for composition and proportions. Add realistic depth, dramatic lighting, and atmospheric effects such as reflections, sky, and shadows, so the scene feels immersive and cinematic. The final result should look like a stunning photograph, true to the layout of the sketch but elevated into a vivid, breathtaking real-world scene
    """

    static let imageEditPrompt = """
    Use the sketch as a guide for editing the base image. The sketch marks indicate where and how to modify the image. Interpret the sketch strokes as instructions for changes - adding elements, removing objects, or transforming areas. Blend edits seamlessly with the original image while following the sketch guidance. Maintain the style and quality of the original image.
    """

    // Track if we've had at least one generation
    var hasGeneratedImage: Bool {
        !sessionImages.isEmpty
    }

    // Track the prompt before image was loaded (to restore later)
    private var promptBeforeImageEdit: String? = nil

    var hasCustomPrompt: Bool {
        customPrompt != Self.defaultPrompt && customPrompt != Self.imageEditPrompt && customPrompt != currentDefaultPrompt
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

        // Pre-select Photo preset if prompt is the old default or the photo preset prompt
        let photoSketchPrompt = "Transform this sketch into: \(StylePreset.photorealistic.promptSnippet)"
        if customPrompt == Self.defaultPrompt || customPrompt == photoSketchPrompt {
            applyStylePreset(.photorealistic)
        }
    }

    private func savePrompt() {
        UserDefaults.standard.set(customPrompt, forKey: "customPrompt")
    }

    private func saveSettings() {
        if let data = try? JSONEncoder().encode(generationSettings) {
            UserDefaults.standard.set(data, forKey: "generationSettings")
        }
    }

    var currentDefaultPrompt: String {
        if baseImage != nil {
            return "Edit the base image using the sketch as a guide. Apply the edit in a \(StylePreset.photorealistic.promptSnippet) style. Blend changes seamlessly with the original image."
        }
        return "Transform this sketch into: \(StylePreset.photorealistic.promptSnippet)"
    }

    func resetPromptToDefault() {
        applyStylePreset(.photorealistic)
    }

    func applyStylePreset(_ preset: StylePreset) {
        selectedStylePreset = preset
        if baseImage != nil {
            // Image edit mode - style presets modify how the edit is applied
            customPrompt = "Edit the base image using the sketch as a guide. Apply the edit in a \(preset.promptSnippet) style. Blend changes seamlessly with the original image."
        } else {
            // Sketch to image mode
            customPrompt = "Transform this sketch into: \(preset.promptSnippet)"
        }
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
        let hadImage = baseImage != nil
        let willHaveImage = image != nil

        baseImage = image

        // Auto-switch prompt based on whether we have a base image
        if willHaveImage && !hadImage {
            // Switching to image edit mode - save current prompt and switch
            if customPrompt == currentDefaultPrompt || customPrompt == Self.defaultPrompt {
                promptBeforeImageEdit = nil
            } else {
                promptBeforeImageEdit = customPrompt
            }
            applyStylePreset(.photorealistic)
        } else if !willHaveImage && hadImage {
            // Removing image - restore previous prompt
            if let savedPrompt = promptBeforeImageEdit {
                customPrompt = savedPrompt
                selectedStylePreset = nil
            } else {
                applyStylePreset(.photorealistic)
            }
            promptBeforeImageEdit = nil
        }
    }

    func setSessionIndex(_ index: Int) {
        guard index >= 0 && index < sessionImages.count else { return }
        sessionIndex = index
        currentPreviewImage = sessionImages[index]
    }
}
