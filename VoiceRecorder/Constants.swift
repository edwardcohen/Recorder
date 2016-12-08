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

struct Constants {
    struct MainParameters {
        static let durations = 90.0
    }
}
