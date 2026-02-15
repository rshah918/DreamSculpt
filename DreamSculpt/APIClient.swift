//
//  APIClient.swift
//  DreamSculpt
//
//  Created by Rahul Shah on 8/31/25.
//

import Foundation
import UIKit

struct ImageRequest: Codable {
    var prompt: String
    var init_images: [String]   // or [Data] if multiple images
    var denoising_strength: Double
    var steps: Int
    var cfg_scale: Double
    var batch_count: Int
    var height: Int
    var width: Int

    init(image: UIImage, prompt: String, settings: GenerationSettings) {
        self.prompt = prompt
        self.init_images = [image.pngData()!.base64EncodedString()]
        self.denoising_strength = settings.denoisingStrength
        self.steps = settings.steps
        self.cfg_scale = settings.cfgScale
        self.batch_count = 1
        self.height = Int(image.size.height * 3)
        self.width = Int(image.size.width * 3)
    }
}

struct APIResponseSchema: Decodable {
    let images: [String]
}

func uploadDrawing(image: UIImage, prompt: String, settings: GenerationSettings) async -> UIImage? {
    let url = URL(string: "http://127.0.0.1:8003/sdapi/v1/img2img")
    let body = ImageRequest(image: image, prompt: prompt, settings: settings)
    do {
        let jsonData = try JSONEncoder().encode(body)
        var request = URLRequest(url: url!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
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
        if decodedResponse.images.isEmpty == false{
            let decodedImage: UIImage = UIImage(data: Data(base64Encoded: decodedResponse.images[0])!)!
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
