//
//  ViewController.swift
//  CoreMLTest
//
//  Created by Luke Lee on 2024/12/20.
//

import UIKit
import CoreML

class ViewController: UIViewController {
    
    private let objDetector = try? obj_det_v2()
    
    private var detector = ObjectDetector()
    
    private var vectorModlel = ObjectVectorModel()
    
    private var pageData: [DetectionResult] = [] {
        didSet {
            imagePickerCollectionView.reloadData()
        }
    }
    
    private var selectedImageIndex: Int? {
        didSet {
            guard
                let selectedImageIndex = selectedImageIndex,
                selectedImageIndex < pageData.count
            else {
                imageView.image = nil
                textDisplay.text = "Error"
                return
            }
            let item = pageData[selectedImageIndex]
            updateUI(item)
        }
    }
    
    private lazy var impageInputButton: MediaPicker = {
        let picker = MediaPicker()
        picker.selectionLimit = 1
        picker.imageSize = .scaleToFit(CGSize(width: 384, height: 640))
        picker.delegate = self
        return picker
    }()
    
    private let imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    
    private let imagePickerHeight: CGFloat = 50
    
    private let textDisplay: UILabel = {
        let lbl = UILabel()
        lbl.font = .systemFont(ofSize: 18)
        lbl.textColor = .white
        lbl.translatesAutoresizingMaskIntoConstraints = false
        lbl.numberOfLines = 1
        lbl.lineBreakMode = .byTruncatingMiddle
        lbl.textAlignment = .center
        return lbl
    }()
    
    private lazy var imagePickerCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = CGSize(width: imagePickerHeight, height: imagePickerHeight)
        layout.minimumLineSpacing = 8
        layout.minimumInteritemSpacing = 8
        
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.translatesAutoresizingMaskIntoConstraints = false
        cv.dataSource = self
        cv.delegate = self
        cv.register(ImagePickerCell.self, forCellWithReuseIdentifier: "\(ImagePickerCell.self)")
        cv.backgroundColor = .clear
        cv.showsHorizontalScrollIndicator = false
        cv.contentInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        return cv
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        title = "Object Detection"
        setupNavigationBar()
    }
    
    private lazy var sendVectorButton = UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(handleUploadVectorPressed))
    
    private func setupNavigationBar() {
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .camera, target: self, action: #selector(handleCameraButtonPressed))
        navigationItem.leftBarButtonItem = sendVectorButton
        sendVectorButton.isHidden = true
    }
    
    private func setupView() {
        view.backgroundColor = .white
        
        let pickImageButton = UIButton(type: .system)
        pickImageButton.setTitle("Select Image", for: .normal)
        pickImageButton.translatesAutoresizingMaskIntoConstraints = false
        pickImageButton.addTarget(self, action: #selector(handleCameraButtonPressed), for: .touchUpInside)
        view.addSubview(pickImageButton)
        
        view.addSubview(imageView)
        
        let textContainer = UIView()
        textContainer.addSubview(textDisplay)
        textContainer.translatesAutoresizingMaskIntoConstraints = false
        textContainer.backgroundColor = .black.withAlphaComponent(0.5)
        view.addSubview(textContainer)
        
        let imagePickerContainer = UIView()
        imagePickerContainer.translatesAutoresizingMaskIntoConstraints = false
        imagePickerContainer.backgroundColor = .lightGray
        imagePickerContainer.addSubview(imagePickerCollectionView)
        view.addSubview(imagePickerContainer)
        
        NSLayoutConstraint.activate([
            pickImageButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            pickImageButton.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            
            imagePickerContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            imagePickerContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            imagePickerContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            imagePickerCollectionView.heightAnchor.constraint(equalToConstant: imagePickerHeight),
            imagePickerCollectionView.leadingAnchor.constraint(equalTo: imagePickerContainer.leadingAnchor),
            imagePickerCollectionView.trailingAnchor.constraint(equalTo: imagePickerContainer.trailingAnchor),
            imagePickerCollectionView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            imagePickerCollectionView.topAnchor.constraint(equalTo: imagePickerContainer.topAnchor, constant: 16),
            
            imageView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: imagePickerContainer.topAnchor),
            
            textContainer.leadingAnchor.constraint(equalTo: imageView.leadingAnchor),
            textContainer.trailingAnchor.constraint(equalTo: imageView.trailingAnchor),
            textContainer.bottomAnchor.constraint(equalTo: imageView.bottomAnchor),
            textContainer.heightAnchor.constraint(equalToConstant: 48),
            
            textDisplay.leadingAnchor.constraint(equalTo: textContainer.leadingAnchor, constant: 16),
            textDisplay.trailingAnchor.constraint(equalTo: textContainer.trailingAnchor, constant: -16),
            textDisplay.centerYAnchor.constraint(equalTo: textContainer.centerYAnchor)
        ])
    }
    
    @objc private func handleUploadVectorPressed(_ sender: UIBarButtonItem) {
        guard
            let selectedItemIndex = imagePickerCollectionView.indexPathsForSelectedItems?.first?.item,
            selectedItemIndex < pageData.count
        else {
            return
        }
        sender.isEnabled = false
        let item = pageData[selectedItemIndex]
        print("start process image in embedding model...")
        processVectorData(item) { [weak self] result in
            switch result {
            case .success(let vector):
                print("embedding model processing success, sending vector data to server")
                self?.sendVectors([vector]) { vectorResult in
                    DispatchQueue.main.async {
                        sender.isEnabled = true
                    }
                    switch vectorResult {
                    case .success(let successResponse):
                        print("vector api success with response:", successResponse)
                    case .failure(let error):
                        print("vector api failure with error:", error)
                    }
                }
            case .failure(let error):
                print("embedding model processing failed with error:", error)
            }
            
        }
    }
    
    private func sendVectors(_ vectors: [[Double]], completion: @escaping (Result<String, Error>) -> Void) {
        guard let url = URL(string: "https://vectorsearchshoalter.hk.dev:9453/search_vec") else {
            print("Invalid URL")
            return
        }
        
        let requestBody: [String: Any] = [ "vectors": vectors ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody, options: []) else {
            print("Failed to serialize JSON")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            
            if let error = error {
                print("Error: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard
                let httpResponse = response as? HTTPURLResponse,
                httpResponse.statusCode >= 200 && httpResponse.statusCode < 400
            else {
                let error = NSError(domain: "vector url", code: 0, userInfo: ["status code": "error status code"])
                completion(.failure(error))
                return
            }
            
            guard
                let data = data,
                let responseString = String(data: data, encoding: .utf8)
            else {
                let error = NSError(domain: "vector url", code: 0, userInfo: ["response data": "incorrect response data"])
                completion(.failure(error))
                return
            }
            
            completion(.success(responseString))
        }
        
        task.resume()
    }
    
    @objc private func handleCameraButtonPressed(_ sender: UIButton) {
        impageInputButton.showPickerSelectionActionSheet(
            on: self,
            sourceView: sender,
            popoverArrowDirection: .down,
            menuTitle: nil,
            menuMessage: nil
        )
    }
    
    private func updateUI(_ item: DetectionResult) {
        imageView.image = item.image
        if selectedImageIndex != 0 {
            sendVectorButton.isHidden = false
            textDisplay.text = item.identifier + "  " + "\(item.confidence * 100)"
        } else {
            sendVectorButton.isHidden = true
            textDisplay.text = "Original Image"
        }
    }
    
    private func processVectorData(_ item: DetectionResult, handler: @escaping (Result<[Double], Error>) -> Void) {
        DispatchQueue.global().async {
            do {
                let result = try self.vectorModlel.process(image: item.image)
                guard result.count > 0 else {
                    handler(.failure(EmbeddingModelError.noResult))
                    return
                }
                var doubleArray: [Double] = []
                for i in 0..<result.count {
                    doubleArray.append(result[i].doubleValue)
                }
                handler(.success(doubleArray))
            } catch {
                print("failed to process image buffer:", error)
                handler(.failure(error))
            }
        }
    }
}

extension ViewController: MediaPickerDelegate {
    func picker(_ picker: MediaPicker, didFinishPicking results: [PickedMediaResult]) {
        guard let result = results.first else { return } // only support single image
        pageData.removeAll()
        selectedImageIndex = nil
        
        switch result {
        case .success(let obj):
            guard let image = UIImage(data: obj.data) else { break }
            do {
                pageData.append(DetectionResult(image: image, identifier: "", confidence: 0))
                selectedImageIndex = 0

                try detector.detectObjects(in: image) { [weak self] detectionResults in
                    self?.pageData.append(contentsOf: detectionResults)
                }
                
            } catch {
                print(error)
            }
            
        case .failure(let error):
            print(error)
        }
    }
    
    func pickerDidCancel(_ picker: MediaPicker) {
        print("did cancel")
    }
}

extension ViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        selectedImageIndex = indexPath.item
    }
}

extension ViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return pageData.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "\(ImagePickerCell.self)", for: indexPath) as! ImagePickerCell
        let item = pageData[indexPath.item]
        cell.imageView.image = item.image
        return cell
    }
}
