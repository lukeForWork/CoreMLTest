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
                        guard let croppedImage = image.crop(to: data.rect) else { return nil }
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
            var rect = prediction.boundingBox  // normalized xywh, origin lower left
            switch UIDevice.current.orientation {
            case .portraitUpsideDown:
                rect = CGRect(x: 1.0 - rect.origin.x - rect.width,
                              y: 1.0 - rect.origin.y - rect.height,
                              width: rect.width,
                              height: rect.height)
            case .unknown:
                print("The device orientation is unknown, the predictions may be affected")
                fallthrough
            default: break
            }
            
            results.append((rect: rect,
                            identifier: prediction.labels[0].identifier,
                            confidence: prediction.labels[0].confidence))
        }
//                    if ratio >= 1 {  // iPhone ratio = 1.218
//                        let offset = (1 - ratio) * (0.5 - rect.minX)
//                        let transform = CGAffineTransform(scaleX: 1, y: -1).translatedBy(x: offset, y: -1)
//                        rect = rect.applying(transform)
//                        rect.size.width *= ratio
//                    } else {  // iPad ratio = 0.75
//                        let offset = (ratio - 1) * (0.5 - rect.maxY)
//                        let transform = CGAffineTransform(scaleX: 1, y: -1).translatedBy(x: 0, y: offset - 1)
//                        rect = rect.applying(transform)
//                        ratio = (height / width) / (3.0 / 4.0)
//                        rect.size.height /= ratio
//                    }
//                    
//                    // Scale normalized to pixels [375, 812] [width, height]
//                    rect = VNImageRectForNormalizedRect(rect, Int(width), Int(height))
//                    
//                    // The labels array is a list of VNClassificationObservation objects,
//                    // with the highest scoring class first in the list.
//                    let bestClass = prediction.labels[0].identifier
//                    let confidence = prediction.labels[0].confidence
//                    // print(confidence, rect)  // debug (confidence, xywh) with xywh origin top left (pixels)
//                    let label = String(format: "%@ %.1f", bestClass, confidence * 100)
//                    let alpha = CGFloat((confidence - 0.2) / (1.0 - 0.2) * 0.9)
//                    // Show the bounding box.
//                    boundingBoxViews[i].show(
//                        frame: rect,
//                        label: label,
//                        color: colors[bestClass] ?? UIColor.white,
//                        alpha: alpha)  // alpha 0 (transparent) to 1 (opaque) for conf threshold 0.2 to 1.0)
//                    
//                    if developerMode {
//                        // Write
//                        if save_detections {
//                            str += String(
//                                format: "%.3f %.3f %.3f %@ %.2f %.1f %.1f %.1f %.1f\n",
//                                sec_day, freeSpace(), UIDevice.current.batteryLevel, bestClass, confidence,
//                                rect.origin.x, rect.origin.y, rect.size.width, rect.size.height)
//                        }
//                    }
//                } else {
//                    boundingBoxViews[i].hide()
//                }
//        } else {
//            let frameAspectRatio = longSide / shortSide
//            let viewAspectRatio = width / height
//            var scaleX: CGFloat = 1.0
//            var scaleY: CGFloat = 1.0
//            var offsetX: CGFloat = 0.0
//            var offsetY: CGFloat = 0.0
//            
//            if frameAspectRatio > viewAspectRatio {
//                scaleY = height / shortSide
//                scaleX = scaleY
//                offsetX = (longSide * scaleX - width) / 2
//            } else {
//                scaleX = width / longSide
//                scaleY = scaleX
//                offsetY = (shortSide * scaleY - height) / 2
//            }
//            
//            for i in 0..<boundingBoxViews.count {
//                if i < predictions.count {
//                    let prediction = predictions[i]
//                    
//                    var rect = prediction.boundingBox
//                    
//                    rect.origin.x = rect.origin.x * longSide * scaleX - offsetX
//                    rect.origin.y =
//                    height
//                    - (rect.origin.y * shortSide * scaleY - offsetY + rect.size.height * shortSide * scaleY)
//                    rect.size.width *= longSide * scaleX
//                    rect.size.height *= shortSide * scaleY
//                    
//                    let bestClass = prediction.labels[0].identifier
//                    let confidence = prediction.labels[0].confidence
//                    
//                    let label = String(format: "%@ %.1f", bestClass, confidence * 100)
//                    let alpha = CGFloat((confidence - 0.2) / (1.0 - 0.2) * 0.9)
//                    // Show the bounding box.
//                    boundingBoxViews[i].show(
//                        frame: rect,
//                        label: label,
//                        color: colors[bestClass] ?? UIColor.white,
//                        alpha: alpha)  // alpha 0 (transparent) to 1 (opaque) for conf threshold 0.2 to 1.0)
//                } else {
//                    boundingBoxViews[i].hide()
//                }
//            }
//        }
//        // Write
//        if developerMode {
//            if save_detections {
//                saveText(text: str, file: "detections.txt")  // Write stats for each detection
//            }
//            if save_frames {
//                str = String(
//                    format: "%.3f %.3f %.3f %.3f %.1f %.1f %.1f\n",
//                    sec_day, freeSpace(), memoryUsage(), UIDevice.current.batteryLevel,
//                    self.t1 * 1000, self.t2 * 1000, 1 / self.t4)
//                saveText(text: str, file: "frames.txt")  // Write stats for each image
//            }
//        }
        
        // Debug
        // print(str)
        // print(UIDevice.current.identifierForVendor!)
        // saveImage()
        return results
    }

}
