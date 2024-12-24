//
//  MediaPicker.swift
//  CoreMLTest
//
//  Created by Luke Lee on 2023/10/24.
//

import UIKit
import PhotosUI
import CoreServices

enum MediaPickerError: Error {
    case fileTooLarge
    case fileParseError
    case jpgCompressionFile
    case typeCastingError(Error?)
    case loadError(Error)
    case other(Error)
}

protocol MediaPickerDelegate: NSObject {
    func picker(_ picker: MediaPicker, didFinishPicking results: [PickedMediaResult])
    func pickerDidCancel(_ picker: MediaPicker)
}

class MediaPicker: NSObject {

    weak var delegate: MediaPickerDelegate?
    
    var fileMaxMB: Int = 2
    
    /// image will be scaled if either width or height larger than this property. This property can be set before picking
    var imageSize: TargetImageSize = .max(CGSize(width: 1280, height: 1280))
    
    var selectionLimit = 10
    
    /// create a UIImagePickerController with sourceType camera
    var camera: UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.allowsEditing = false
        picker.cameraDevice = .rear
        picker.cameraCaptureMode = .photo
        picker.delegate = self
        return picker
    }
    
    /// create a photo library UIViewController (PHPickerViewController / UIImagePickerController by iOS version)
    var photoLibrary: UIViewController {
        if #available(iOS 14.0, *) {
            var configuration = PHPickerConfiguration(photoLibrary: .shared())
            configuration.filter = .images
            configuration.selectionLimit = selectionLimit
            configuration.preferredAssetRepresentationMode = .compatible
            if #available(iOS 15.0, *) {
                configuration.selection = .ordered
            }
            
            let picker = PHPickerViewController(configuration: configuration)
            picker.delegate = self
            picker.modalPresentationStyle = .fullScreen
            return picker
        } else {
            let picker = UIImagePickerController()
            picker.sourceType = .photoLibrary
            picker.mediaTypes = [kUTTypeImage as String]
            if let mediaTypes = UIImagePickerController.availableMediaTypes(for: .photoLibrary) {
                picker.mediaTypes = mediaTypes
            }
            picker.delegate = self
            return picker
        }
    }
    
    private func getDataInRightSize(image: UIImage, compressionQuality: CGFloat = 0.9) throws -> Data {
        guard let imgData = image.jpegData(compressionQuality: compressionQuality), imgData.count > 0 else {
            throw MediaPickerError.jpgCompressionFile
        }
        if imgData.count > fileMaxMB * 1_000_000 && compressionQuality > 0.2 {
            // if it already compressed with 0.2, dont need to try 0.1, just return it for the server to decide if it's still too big
            return try getDataInRightSize(image: image, compressionQuality: compressionQuality - 0.1)
        }
        return imgData
    }
    
    private func showGoToSettingAlert(on vc: UIViewController, completion: @escaping () -> Void) {

        let alertActions =
        [
            UIAlertAction(title: "前往設定", style: .default) { action in
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    completion()
                    UIApplication.shared.open(url)
                }

            },
            UIAlertAction(title: "取消", style: .cancel) { action in
                completion()
            }
        ]
        
        vc.presentAlert(alertTitle: "上傳圖片功能需要相機/相簿權限", alertMessage: nil, actions: alertActions)
    }
    
    func showCamera(on vc: UIViewController, unsuccessCompletion: @escaping () -> Void) {
        
        let cameraMediaType = AVMediaType.video
        let cameraAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: cameraMediaType)
        
        switch cameraAuthorizationStatus {
        case .restricted:
            print("Camera function is restricted")
        case .denied:
            showGoToSettingAlert(on: vc, completion: unsuccessCompletion)
        case .authorized:
            vc.present(camera, animated: true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] accessGranted in
                DispatchQueue.main.async {
                    if accessGranted, let camera = self?.camera {
                        vc.present(camera, animated: true)
                    } else {
                        unsuccessCompletion()
                    }
                }
            }
        @unknown default:
            print("unknown case")
        }
    }
    
    func showPhotoLibrary(on vc: UIViewController) {
        vc.present(photoLibrary, animated: true)
    }
    
    func showPickerSelectionActionSheet(
        on vc: UIViewController,
        sourceView: UIView,
        popoverArrowDirection: UIPopoverArrowDirection,
        menuTitle: String? = nil,
        menuMessage: String? = nil,
        unsuccessCompletion: (() -> Void)? = nil,
        cancelCompletion: (() -> Void)? = nil
    ) {
        let alert = UIAlertController(
            title: menuTitle,
            message: menuMessage,
            preferredStyle: .actionSheet
        )
        
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            let cameraAction = UIAlertAction(
                title: "Camera",
                style: .default
            ) { [weak self] action in
                self?.showCamera(on: vc, unsuccessCompletion: unsuccessCompletion ?? {})
            }
            alert.addAction(cameraAction)
        }
        
        let photoLibraryAction = UIAlertAction(
            title: "Album",
            style: .default
        ) { [weak self] action in
            self?.showPhotoLibrary(on: vc)
        }
        alert.addAction(photoLibraryAction)
        
        let cancelAction = UIAlertAction(
            title: "Cancel",
            style: .cancel
        ) { action in
            cancelCompletion?()
        }
        alert.addAction(cancelAction)
        
        if let ppvc = alert.popoverPresentationController {
            ppvc.sourceView = sourceView
            ppvc.sourceRect = sourceView.bounds
            ppvc.permittedArrowDirections = popoverArrowDirection
        }
        
        vc.present(alert, animated: true)
    }
    
    private func cancelPicker(_ picker: UIViewController) {
        guard !picker.isBeingDismissed else { return }
        picker.dismiss(animated: true) {
            self.delegate?.pickerDidCancel(self)
        }
    }
}

extension MediaPicker: PHPickerViewControllerDelegate {
    @available(iOS 14.0, *)
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        guard !results.isEmpty else {
            cancelPicker(picker)
            return
        }
        
        guard !picker.isBeingDismissed else { return }
//        Loader.startLoadingOnEntireScreen()
        picker.dismiss(animated: true) {
            
            var imageDatas = [Int : PickedMediaResult]()
            
            let group = DispatchGroup()
            
            for (index, result) in results.enumerated() {
                
                group.enter()
                // handle normal photo
                if result.itemProvider.canLoadObject(ofClass: UIImage.self) {
                    result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] object, err in
                        defer { group.leave() }
                        guard let strongSelf = self else { return }
                        
                        
                        if let err = err {
                            print("error loading photo object:", err)
                            imageDatas[index] = .failure(.loadError(err))
                            return
                        }
                        
                        guard let image = (object as? UIImage)?.normalized(targetSize: strongSelf.imageSize) else {
                            imageDatas[index] = .failure(.typeCastingError(nil))
                            return
                        }
                        
                        do {
                            let jpgData = try strongSelf.getDataInRightSize(image: image)
                            let mediaResult = PickedMediaData(id: result.assetIdentifier, data: jpgData)
                            imageDatas[index] = .success(mediaResult)
                        } catch (let err as MediaPickerError) {
                            imageDatas[index] = .failure(err)
                        } catch let err {
                            imageDatas[index] = .failure(.other(err))
                        }
                    }
                } else {
                    
                    // handle raw photo
                    result.itemProvider.loadFileRepresentation(forTypeIdentifier: "public.image") { [weak self] url, err in
                        defer { group.leave() }
                        
                        if let err = err {
                            print("error loading photo file", err)
                            imageDatas[index] = .failure(.loadError(err))
                            return
                        }
                        
                        guard
                            let strongSelf = self,
                            let url = url,
                            let data = NSData(contentsOf: url),
                            let source = CGImageSourceCreateWithData(data, nil),
                            let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil),
                            let image = UIImage(cgImage: cgImage).normalized(targetSize: strongSelf.imageSize)
                        else {
                            imageDatas[index] = .failure(MediaPickerError.fileParseError)
                            return
                        }
                        
                        do {
                            let jpgData = try strongSelf.getDataInRightSize(image: image)
                            let mediaResult = PickedMediaData(id: result.assetIdentifier, data: jpgData)
                            imageDatas[index] = .success(mediaResult)
                            
                        } catch (let err as MediaPickerError) {
                            imageDatas[index] = .failure(err)
                            
                        } catch let err {
                            imageDatas[index] = .failure(.other(err))
                            
                        }
                    }
                }
            }
            
            group.notify(queue: .main) { [weak self] in
//                Loader.endLoadingOnEntireScreen()
                guard let strongSelf = self else { return }
                let sortedKey = imageDatas.keys.sorted()
                strongSelf.delegate?.picker(strongSelf, didFinishPicking: sortedKey.compactMap { imageDatas[$0] })
            }
        }
    }
}

extension MediaPicker: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        guard !picker.isBeingDismissed else { return }

//        Loader.startLoadingOnEntireScreen()
        picker.dismiss(animated: true) {
//            Loader.endLoadingOnEntireScreen()
            var imageDatas = [PickedMediaResult]()
            do {
                
                if
                    let originalImage = info[UIImagePickerController.InfoKey.originalImage] as? UIImage,
                    let normalizedImage = originalImage.normalized(targetSize: self.imageSize)
                {
                    let imageData = try self.getDataInRightSize(image: normalizedImage)
                    let mediaResult = PickedMediaData(id: nil, data: imageData)
                    imageDatas = [.success(mediaResult)]
                }
                
            } catch let error as MediaPickerError {
                imageDatas = [.failure(error)]
                
            } catch {
                imageDatas = [.failure(.other(error))]
                
            }
            
            self.delegate?.picker(self, didFinishPicking: imageDatas)
        }
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        cancelPicker(picker)
    }
}

struct PickedMediaData {
    let id: String?
    let data: Data
}

typealias PickedMediaResult = Result<PickedMediaData, MediaPickerError>
