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
    
    private var images: [UIImage?] = []
    
    private lazy var impageInputButton: MediaPicker = {
        let picker = MediaPicker()
        picker.selectionLimit = 1
        picker.imageSize = .scaleToFill(CGSize(width: 384, height: 640))
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
    
    private func setupNavigationBar() {
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .camera, target: self, action: #selector(handleCameraButtonPressed))
    }
    
    private func setupView() {
        view.backgroundColor = .white
        
        view.addSubview(imageView)
        
        let imagePickerContainer = UIView()
        imagePickerContainer.translatesAutoresizingMaskIntoConstraints = false
        imagePickerContainer.backgroundColor = .lightGray
        imagePickerContainer.addSubview(imagePickerCollectionView)
        view.addSubview(imagePickerContainer)
        
        NSLayoutConstraint.activate([
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
            imageView.bottomAnchor.constraint(equalTo: imagePickerContainer.topAnchor)
        ])
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
    
    private func detectObjects(in image: UIImage, handler: @escaping ([UIImage]) -> Void) throws {
        try detector.detectObjects(in: image) { imgs in
            handler(imgs)
        }
    }
}

extension ViewController: MediaPickerDelegate {
    func picker(_ picker: MediaPicker, didFinishPicking results: [PickedMediaResult]) {
        images.removeAll()
        defer {
            imagePickerCollectionView.reloadData()
        }
        
        guard let result = results.first else { return } // only support single image
        
        
        switch result {
        case .success(let obj):
            guard let image = UIImage(data: obj.data) else { break }
            do {
                imageView.image = image
                images.append(image)
                try detectObjects(in: image) { [weak self] imgs in
                    self?.images.append(contentsOf: imgs)
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
        let image = images[indexPath.item]
        imageView.image = image
        
        if let buffer = image?.cvPixelBuffer {
            do {
                let result = try vectorModlel.process(imageBuffer: buffer)
                print(result)
            } catch {
                print("failed to process image buffer:", error)
            }
        }
    }
}

extension ViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return images.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "\(ImagePickerCell.self)", for: indexPath) as! ImagePickerCell
        let image = images[indexPath.item]
        cell.imageView.image = image
        return cell
    }
}
