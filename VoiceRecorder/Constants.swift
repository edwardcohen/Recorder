//
//  Constants.swift
//  VoiceRecorder
//
//  Created by Alex on 02.12.16.
//  Copyright © 2016 CocoaPods. All rights reserved.
//

import Foundation
import UIKit

enum RecordState: Int {
    case None
    case OneTime
    case Continuous
    case Pause
    case Done
}

class Gradient {
    let colorTop =  UIColor.clear.cgColor
    let colorBottom = UIColor.black.cgColor
    let gl: CAGradientLayer
    
    init() {
        gl = CAGradientLayer()
        gl.colors = [colorTop, colorBottom]
        gl.locations = [0, 0.2]
    }
}

struct Constants {
    struct MainParameters {
        static let durations = 90.0
    }
}
