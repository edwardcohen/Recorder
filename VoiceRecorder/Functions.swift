//
//  Functions.swift
//  VoiceRecorder
//
//  Created by Alex on 16.12.16.
//  Copyright © 2016 CocoaPods. All rights reserved.
//

import Foundation
import UIKit

class Functions {
    class func getStringHeight(_ text: String?, font: UIFont, width: CGFloat) -> CGFloat {
        if let text = text {
            let label: UILabel = UILabel(frame: CGRect(x: 0, y: 0, width: width, height: CGFloat.greatestFiniteMagnitude))
            label.numberOfLines = 0
            label.lineBreakMode = NSLineBreakMode.byWordWrapping
            label.font = font
            label.text = text
            
            label.sizeToFit()
            if label.frame.height > 16 {
                return label.frame.height
            } else {
                return 16
            }
        } else {
            return 16
        }
    }
    
    class func timeString(_ time: Double) -> String {
        let minutes = Int(time) / 60 % 60
        let seconds = Int(time) % 60
        return String(format:"%02i:%02i", minutes, seconds)
    }
}
