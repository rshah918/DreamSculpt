//
//  HistoryManager.swift
//  DreamSculpt
//

import Foundation
import UIKit

class HistoryManager {
    static let shared = HistoryManager()

    private let historyKey = "generationHistory"
    private let maxRecords = 50
    private let maxStorageMB: Double = 500

    private var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    private var historyDirectory: URL {
        let dir = documentsDirectory.appendingPathComponent("GenerationHistory", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    func loadHistory() -> [GenerationRecord] {
        guard let data = UserDefaults.standard.data(forKey: historyKey),
              let records = try? JSONDecoder().decode([GenerationRecord].self, from: data) else {
            return []
        }
        return records.sorted { $0.timestamp > $1.timestamp }
    }

    func saveHistory(_ records: [GenerationRecord]) {
        if let data = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(data, forKey: historyKey)
        }
    }

    func saveGeneration(sketch: UIImage, result: UIImage) -> GenerationRecord? {
        let id = UUID()
        let sketchFilename = "\(id.uuidString)_sketch.png"
        let resultFilename = "\(id.uuidString)_result.png"

        guard saveImage(sketch, filename: sketchFilename),
              saveImage(result, filename: resultFilename) else {
            return nil
        }

        let record = GenerationRecord(
            id: id,
            timestamp: Date(),
            sketchFilename: sketchFilename,
            resultFilename: resultFilename
        )

        var history = loadHistory()
        history.insert(record, at: 0)
        cleanupIfNeeded(&history)
        saveHistory(history)

        return record
    }

    func deleteGeneration(_ record: GenerationRecord) {
        deleteImage(filename: record.sketchFilename)
        deleteImage(filename: record.resultFilename)

        var history = loadHistory()
        history.removeAll { $0.id == record.id }
        saveHistory(history)
    }

    func loadImage(filename: String) -> UIImage? {
        let url = historyDirectory.appendingPathComponent(filename)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    private func saveImage(_ image: UIImage, filename: String) -> Bool {
        let url = historyDirectory.appendingPathComponent(filename)
        guard let data = image.pngData() else { return false }
        do {
            try data.write(to: url)
            return true
        } catch {
            print("Failed to save image: \(error)")
            return false
        }
    }

    private func deleteImage(filename: String) {
        let url = historyDirectory.appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: url)
    }

    private func cleanupIfNeeded(_ history: inout [GenerationRecord]) {
        while history.count > maxRecords {
            if let oldest = history.popLast() {
                deleteImage(filename: oldest.sketchFilename)
                deleteImage(filename: oldest.resultFilename)
            }
        }

        var totalSize = calculateTotalSize()
        while totalSize > maxStorageMB * 1024 * 1024 && !history.isEmpty {
            if let oldest = history.popLast() {
                deleteImage(filename: oldest.sketchFilename)
                deleteImage(filename: oldest.resultFilename)
                totalSize = calculateTotalSize()
            }
        }
    }

    private func calculateTotalSize() -> Double {
        let urls = try? FileManager.default.contentsOfDirectory(
            at: historyDirectory,
            includingPropertiesForKeys: [.fileSizeKey]
        )
        return urls?.reduce(0.0) { total, url in
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            return total + Double(size)
        } ?? 0
    }

    func clearAllHistory() {
        let history = loadHistory()
        for record in history {
            deleteImage(filename: record.sketchFilename)
            deleteImage(filename: record.resultFilename)
        }
        saveHistory([])
    }
}
