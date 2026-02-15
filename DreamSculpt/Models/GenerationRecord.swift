//
//  GenerationRecord.swift
//  DreamSculpt
//

import Foundation
import UIKit

struct GenerationRecord: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let sketchFilename: String
    let resultFilename: String

    init(id: UUID = UUID(), timestamp: Date = Date(), sketchFilename: String, resultFilename: String) {
        self.id = id
        self.timestamp = timestamp
        self.sketchFilename = sketchFilename
        self.resultFilename = resultFilename
    }
}

extension GenerationRecord {
    var sketchImage: UIImage? {
        HistoryManager.shared.loadImage(filename: sketchFilename)
    }

    var resultImage: UIImage? {
        HistoryManager.shared.loadImage(filename: resultFilename)
    }
}
