//
//  APIClient.swift
//  DreamSculpt
//
//  Created by Rahul Shah on 8/31/25.
//

import Foundation
import UIKit

struct ImageRequest: Codable {
    var text_prompt: String
    var image_prompt: String

    init?(image: UIImage, prompt: String) {
        guard let pngData = image.pngData() else { return nil }
        self.text_prompt = prompt
        self.image_prompt = "data:image/png;base64," + pngData.base64EncodedString()
    }
}

struct APIResponseSchema: Decodable {
    let generated_image: String
}

func uploadDrawing(image: UIImage, prompt: String, settings: GenerationSettings, sessionId: String) async -> UIImage? {
    guard let url = URL(string: "https://13.221.123.53.sslip.io/generate") else {
        print("Invalid API URL")
        return nil
    }
    guard let body = ImageRequest(image: image, prompt: prompt) else {
        print("Failed to encode image to PNG")
        return nil
    }
    do {
        let jsonData = try JSONEncoder().encode(body)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(sessionId, forHTTPHeaderField: "Session-Id")
        request.httpBody = jsonData
        request.timeoutInterval = 60
        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse {
            print("Status code: \(httpResponse.statusCode)")
        }

        let decodedResponse = try JSONDecoder().decode(APIResponseSchema.self, from: data)

        guard !decodedResponse.generated_image.isEmpty,
              let imageData = Data(base64Encoded: decodedResponse.generated_image),
              let decodedImage = UIImage(data: imageData) else {
            print("Failed to decode generated image")
            return nil
        }
        return decodedImage

    } catch {
        print("Upload failed with error: \(error)")
        return nil
    }
}
