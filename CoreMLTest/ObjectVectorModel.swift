//
//  ObjectVectorModel.swift
//  CoreMLTest
//
//  Created by Luke Lee on 2024/12/27.
//

import UIKit
import CoreML

enum EmbeddingModelError: Error {
    case typeCastingError
    case noResult
}

class ObjectVectorModel {
    let embModel: emb_model = {
        do {
            return try emb_model()
        } catch {
            fatalError("failed to load emb model")
        }
    }()
    
    func process(image: UIImage) throws -> MLMultiArray {
        guard let imageBuffer = image.toCVPixelBuffer(size: CGSize(width: 224, height: 224)) else {
            throw EmbeddingModelError.typeCastingError
        }
        print("cropped image size", imageBuffer.sizeInKb())
        return try embModel.prediction(x: imageBuffer).var_1262
    }
}

extension CVPixelBuffer {
    
    func sizeInKb() -> Double {
        // Lock the base address to safely access the pixel buffer memory
        CVPixelBufferLockBaseAddress(self, .readOnly)
        
        defer {
            // Unlock the base address when done
            CVPixelBufferUnlockBaseAddress(self, .readOnly)
        }
        
        // Get the width, height, and bytes per row of the pixel buffer
        let width = CVPixelBufferGetWidth(self)
        let height = CVPixelBufferGetHeight(self)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(self)
        
        // Calculate the total size in bytes
        let totalBytes = height * bytesPerRow
        
        // Convert to kilobytes (1 KB = 1024 bytes)
        let sizeInKB = Double(totalBytes) / 1024.0
        
        return sizeInKB
    }

}
