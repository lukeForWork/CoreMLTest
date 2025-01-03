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
        
        return try embModel.prediction(x: imageBuffer).var_1262
    }
}
