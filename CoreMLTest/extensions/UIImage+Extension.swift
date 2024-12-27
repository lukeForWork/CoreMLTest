//
//  UIImage+Extension.swift
//  CoreMLTest
//
//  Created by Luke Lee on 2024/12/20.
//

import UIKit
import CoreMedia

extension UIImage {
    
    var cvPixelBuffer: CVPixelBuffer? { toCVPixelBuffer() } // UIImage to CVPixelBuffer
    
    func toCVPixelBuffer(size: CGSize? = nil) -> CVPixelBuffer? {
        let size = size ?? self.size
        // Create a dictionary for pixel buffer attributes
        let attributes: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true
        ]
        
        // Create a CVPixelBuffer
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(size.width),
            Int(size.height),
            kCVPixelFormatType_32ARGB, // Common format for Core ML models
            attributes as CFDictionary,
            &pixelBuffer
        )
        
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            print("Error: Could not create CVPixelBuffer")
            return nil
        }
        
        // Lock the base address
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        
        // Create a Core Graphics context
        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ) else {
            print("Error: Could not create CGContext")
            CVPixelBufferUnlockBaseAddress(buffer, .readOnly)
            return nil
        }
        
        // Draw the image into the context
        guard let cgImage = cgImage else {
            print("Error: UIImage does not contain CGImage")
            CVPixelBufferUnlockBaseAddress(buffer, .readOnly)
            return nil
        }
        context.draw(cgImage, in: CGRect(origin: .zero, size: size))
        
        // Unlock the pixel buffer
        CVPixelBufferUnlockBaseAddress(buffer, .readOnly)
        
        return buffer
    }
    
    var cmSampleBuffer: CMSampleBuffer? { toCmSampleBuffer() }
    
    func toCmSampleBuffer(size: CGSize? = nil) -> CMSampleBuffer? {
        guard let pixelBuffer = toCVPixelBuffer(size: size) else { return nil }
        var sampleBuffer: CMSampleBuffer?
        var timingInfo = CMSampleTimingInfo(duration: CMTimeMake(value: 1, timescale: 30),  // 30 fps
                                            presentationTimeStamp: CMTime.zero,
                                            decodeTimeStamp: CMTime.invalid)
        
        var videoInfo: CMVideoFormatDescription?
        let status = CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault,
                                                                  imageBuffer: pixelBuffer,
                                                                  formatDescriptionOut: &videoInfo)
        
        if status == kCVReturnSuccess, let videoInfo = videoInfo {
            CMSampleBufferCreateForImageBuffer(allocator: kCFAllocatorDefault,
                                               imageBuffer: pixelBuffer,
                                               dataReady: true,
                                               makeDataReadyCallback: nil,
                                               refcon: nil,
                                               formatDescription: videoInfo,
                                               sampleTiming: &timingInfo,
                                               sampleBufferOut: &sampleBuffer)
        }
        
        return sampleBuffer
    }
    
    var normalized: UIImage? {
        normalized()
    }
    
    func normalized(targetSize: TargetImageSize? = nil) -> UIImage? {
        
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = true
        format.scale = 1
        
        guard let targetSize = targetSize else {
            let renderer = UIGraphicsImageRenderer(size: size, format: format)
            return renderer.image { _ in
                draw(in: CGRect(origin: .zero, size: size))
            }
        }
        
        switch targetSize {
        case .max(let maxSize):
            let multiplier = max(size.height / maxSize.height, size.width / maxSize.width)
            let scaledSize = multiplier > 1
                ? CGSize(width: size.width / multiplier, height: size.height / multiplier) //scale down if too large
                : size
            
            let renderer = UIGraphicsImageRenderer(size: scaledSize, format: format)
            return renderer.image { _ in
                draw(in: CGRect(origin: .zero, size: scaledSize))
            }
            
        case .scaleToFill(let targetSize):
            // Calculate the scaling factor for scaleAspectFill
            let aspectWidth = targetSize.width / size.width
            let aspectHeight = targetSize.height / size.height
            let aspectRatio = min(aspectWidth, aspectHeight) // Use max for aspect fill
            
            let scaledSize = CGSize(width: size.width * aspectRatio, height: size.height * aspectRatio)
            let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
            
            return renderer.image { context in
                let cropOrigin = CGPoint(
                    x: (targetSize.width - scaledSize.width) / 2,
                    y: (targetSize.height - scaledSize.height) / 2
                )
                
                let rect = CGRect(origin: cropOrigin, size: scaledSize)
                
                draw(in: rect)
            }
        }
        
    }
}

enum TargetImageSize {
    /// crop image to exact size, scale up if the image is smaller
    case scaleToFill(CGSize)
    
    /// image, with fixed aspect ratio, scale down to fit in this CGSize if the source is larger.
    case max(CGSize)
    
    var size: CGSize {
        switch self {
        case .scaleToFill(let size):
            return size
        case .max(let size):
            return size
        }
    }
}
