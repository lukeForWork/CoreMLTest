//
//  ObjectVectorModel.swift
//  CoreMLTest
//
//  Created by Luke Lee on 2024/12/27.
//

import UIKit
import CoreML

class ObjectVectorModel {
    let embModel: emb_model = {
        do {
            return try emb_model()
        } catch {
            fatalError("failed to load emb model")
        }
    }()
    
    func process(imageBuffer: CVPixelBuffer) throws -> MLMultiArray {
        return try embModel.prediction(x: imageBuffer).var_1262
    }
}
