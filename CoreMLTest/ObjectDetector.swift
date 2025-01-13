//
//  ObjectDetector.swift
//  CoreMLTest
//
//  Created by Luke Lee on 2024/12/24.
//

import UIKit
import Vision

enum DetectionError: Error {
    case loadDetectorError
    case typeCastingError
}

struct DetectionResult {
    let image: UIImage
    let identifier: String
    let confidence: VNConfidence
}

class ObjectDetector {
    private var detector: VNCoreMLModel = {
        do {
            let model = try obj_dev_v1().model
            return try VNCoreMLModel(for: model)
        } catch {
            fatalError("Failed to load ML model: \(error)")
        }
    }()
    
    func detectObjects(in image: UIImage, completion: @escaping ([DetectionResult]) -> Void) throws {
        guard let sampleBuffer = image.cmSampleBuffer else {
            throw DetectionError.typeCastingError
        }
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let imageOrientation: CGImagePropertyOrientation = UIDevice.current.orientation == .portraitUpsideDown ? .down : .up
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer,
                                            orientation: imageOrientation,
                                            options: [:])
        let request = getVisionRequest(image: image, handler: completion)
        try handler.perform([request])
    }
    
    private func getVisionRequest(image: UIImage, handler: @escaping ([DetectionResult]) -> Void) -> VNCoreMLRequest {
        let request = VNCoreMLRequest(model: detector) { [weak self] request, error in
            
            if let error = error {
                print("Failed to perform request: \(error)")
                return
            }
            
            guard let observations = request.results as? [VNRecognizedObjectObservation] else {
                print("failed to cast request results as [VNRecognizedObjectObservation]")
                return
            }
            
            if let processedData = self?.process(observations: observations) {
                DispatchQueue.main.async {
                    let detectionResult: [DetectionResult] = processedData.compactMap { data in
                        let rect = CGRect(
                            x: data.rect.origin.x * image.size.width,
                            y: (1 - data.rect.origin.y - data.rect.height) * image.size.height,
                            width: data.rect.width * image.size.width,
                            height: data.rect.height * image.size.height
                        )
                        guard let croppedImage = image.crop(to: rect) else { return nil }
                        print("Normalized Rect: \(data.rect), Pixel Rect: \(rect)")
                        return DetectionResult(image: croppedImage, identifier: data.identifier, confidence: data.confidence)
                    }
                    handler(detectionResult)
                }
            }
        }
        request.imageCropAndScaleOption = .scaleFill  // .scaleFit, .scaleFill, .centerCrop
        return request
    }
    
    private func process(observations: [VNRecognizedObjectObservation]) -> [(rect: CGRect, identifier: String, confidence: VNConfidence)] {
        
        var results = [(rect: CGRect, identifier: String, confidence: VNConfidence)]()
        for prediction in observations {
            results.append((rect: prediction.boundingBox,
                            identifier: prediction.labels[0].identifier,
                            confidence: prediction.labels[0].confidence))
        }
        return results
    }
}
