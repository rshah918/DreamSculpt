//
//  GenerationSettings.swift
//  DreamSculpt
//

import Foundation

struct GenerationSettings: Codable, Equatable {
    var steps: Int
    var denoisingStrength: Double
    var cfgScale: Double

    init(steps: Int = 3, denoisingStrength: Double = 1.0, cfgScale: Double = 4.5) {
        self.steps = steps
        self.denoisingStrength = denoisingStrength
        self.cfgScale = cfgScale
    }

    static let `default` = GenerationSettings()

    static let fast = GenerationSettings(
        steps: 2,
        denoisingStrength: 1.0,
        cfgScale: 4.0
    )

    static let balanced = GenerationSettings(
        steps: 4,
        denoisingStrength: 0.9,
        cfgScale: 5.0
    )

    static let quality = GenerationSettings(
        steps: 8,
        denoisingStrength: 0.85,
        cfgScale: 7.0
    )
}

enum StylePreset: String, CaseIterable, Identifiable {
    case photorealistic = "Photo"
    case oilPainting = "Oil"
    case anime = "Anime"
    case cyberpunk = "Cyber"
    case watercolor = "Water"

    var id: String { rawValue }

    var promptSnippet: String {
        switch self {
        case .photorealistic:
            return "photorealistic, stunning photograph, cinematic lighting, professional photography"
        case .oilPainting:
            return "oil painting style, artistic brushstrokes, gallery quality, masterpiece"
        case .anime:
            return "anime style, vibrant colors, Studio Ghibli inspired, detailed illustration"
        case .cyberpunk:
            return "cyberpunk aesthetic, neon lights, futuristic cityscape, sci-fi atmosphere"
        case .watercolor:
            return "delicate watercolor painting, soft edges, artistic, flowing colors"
        }
    }

    var icon: String {
        switch self {
        case .photorealistic: return "camera.fill"
        case .oilPainting: return "paintbrush.fill"
        case .anime: return "sparkles"
        case .cyberpunk: return "bolt.fill"
        case .watercolor: return "drop.fill"
        }
    }
}
