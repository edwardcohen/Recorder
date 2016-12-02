//
//  Extensions.swift
//  VoiceRecorder
//
//  Created by Anton Komin on 01.12.16.
//  Copyright © 2016 CocoaPods. All rights reserved.
//

import Foundation
import UIKit

extension UIColor {
    
    static var recordBlack: UIColor {
        return UIColor(red: 39/255.0, green: 39/255.0, blue: 39/255.0, alpha: 1.0)
    }
    
    static var recordRed: UIColor {
        return UIColor(red: 255/255.0, green: 60/255.0, blue: 49/255.0, alpha: 1.0)
    }
}

extension UIViewController {
    func addGradientFooter() {
        let view = UIView(frame: CGRect(x: 0, y: self.view.frame.height - 90, width: self.view.frame.width, height: 90))
        let gradient = Gradient().gl
        gradient.frame = view.bounds
        view.layer.addSublayer(gradient)
        view.alpha = 0.4
        self.view.addSubview(view)
    }
}
