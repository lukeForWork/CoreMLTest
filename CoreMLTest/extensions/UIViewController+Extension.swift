//
//  UIViewController+Extension.swift
//  CoreMLTest
//
//  Created by Luke Lee on 2024/12/20.
//

import UIKit

extension UIViewController {
    
    func presentAlert(
        alertTitle: String?,
        alertMessage: String?,
        actions: [UIAlertAction]
    ) {
        
        let alertController = UIAlertController(
            title: alertTitle,
            message: alertMessage,
            preferredStyle: .alert
        )
        
        actions.forEach(alertController.addAction)
        
        
        self.present(alertController, animated: true)
    }
}
