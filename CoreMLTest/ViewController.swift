//
//  ViewController.swift
//  CoreMLTest
//
//  Created by Luke Lee on 2024/12/20.
//

import UIKit
import CoreML

enum DetectionError: Error {
    case loadDetectorError
    case typeCastingError
}

class ViewController: UIViewController {

    private let objDetector = try? obj_det_v2()
    
    private lazy var imagePicker: MediaPicker = {
        let picker = MediaPicker()
        picker.selectionLimit = 1
        picker.imageSize = .scaleToFill(CGSize(width: 384, height: 640))
        picker.delegate = self
        return picker
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        setupButton()
    }
    
    private func setupButton() {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Select Image", for: .normal)
        button.addTarget(self, action: #selector(handleButtonPressed), for: .touchUpInside)
        view.addSubview(button)
        NSLayoutConstraint.activate([
            button.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            button.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    @objc private func handleButtonPressed(_ sender: UIButton) {
        imagePicker.showPickerSelectionActionSheet(
            on: self,
            sourceView: sender,
            popoverArrowDirection: .down,
            menuTitle: nil,
            menuMessage: nil
        )
    }
    
    private func predict(_ image: UIImage) throws -> obj_det_v2Output {
        guard let objDetector = objDetector else {
            throw DetectionError.loadDetectorError
        }
        
        guard let imageBuffer = image.cvPixelBuffer else {
            throw DetectionError.typeCastingError
        }
        
        return try objDetector.prediction(image: imageBuffer, iouThreshold: 0.5, confidenceThreshold: 0.6)
    }
}

extension ViewController: MediaPickerDelegate {
    func picker(_ picker: MediaPicker, didFinishPicking results: [PickedMediaResult]) {
        for result in results {
            
            switch result {
            case .success(let obj):
                guard let image = UIImage(data: obj.data) else { continue }
                do {
                    let prediction = try predict(image)
                    print("prediction.featureNames", prediction.featureNames)
                    print("prediction.confidence", prediction.confidence)
                    print("prediction.coordinates", prediction.coordinates)
                    
                } catch {
                    print(error)
                }
                
            case .failure(let error):
                print(error)
            }
        }
    }
    
    func pickerDidCancel(_ picker: MediaPicker) {
        print("did cancel")
    }
}
