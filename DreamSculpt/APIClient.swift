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

    init(image: UIImage, prompt: String) {
        self.text_prompt = prompt
        self.image_prompt = image.pngData()!.base64EncodedString()
    }
}

struct APIResponseSchema: Decodable {
    let generated_image: String
}

func uploadDrawing(image: UIImage, prompt: String, settings: GenerationSettings, sessionId: String) async -> UIImage? {
    let url = URL(string: "http://127.0.0.1:8000/generate")
    let body = ImageRequest(image: image, prompt: prompt)
    do {
        let jsonData = try JSONEncoder().encode(body)
        var request = URLRequest(url: url!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(sessionId, forHTTPHeaderField: "Session-Id")
        request.httpBody = jsonData
        request.timeoutInterval = 300
        let (data, response) = try await URLSession.shared.data(for: request)
        
        let decodedResponse: APIResponseSchema = try JSONDecoder().decode(APIResponseSchema.self, from: data)
        
        // For debugging, print API response
        if let httpResponse = response as? HTTPURLResponse {
            print("Status code: \(httpResponse.statusCode)")
        }
        if let jsonString = String(data: data, encoding: .utf8) {
            print("Response: \(jsonString)")
        }
        if decodedResponse.generated_image.isEmpty == false{
            let decodedImage: UIImage = UIImage(data: Data(base64Encoded: decodedResponse.generated_image)!)!
            return decodedImage
        }
        else {
            return nil
        }
        
    } catch {
        print("Upload failed with error: \(error)")
        return nil
    }
}

/*
 
 I was able to get sketching working using PencilKit. I was able to link it to the local DrawThings server and get AI upscaling to work upon canvas update.
 
  TODO:
    - Render the returned image back to the UI
        - Animate an exapanding window when AI renders first come in
            - DONE
        - Smooth animations between subsequent AI renders
            - DONE
    - Hit BFL api, hope that its fast.
 
 9/3/2025
 
 I got AI rendering to show up on the UI, made it draggable and expandable. Fixed bug where empty API response erases the last generation.
 
 TODO:
    - Fix dragging bug
    - Connect to nano-banana api or BFL
    - Maybe build a backend
    - Store history
    - Download button
    
    
 */
