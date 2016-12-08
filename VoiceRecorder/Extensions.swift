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

extension Date {
    func lastDayOfMonth() -> Date {
        let calendar = Calendar.current
        let dayRange = calendar.range(of: .day, in: .month, for: self)
        let dayCount = dayRange!.count
        var comp = calendar.dateComponents([.year, .month, .day], from: self)
        
        comp.day = dayCount
        
        return calendar.date(from: comp)!
    }
    
    func firstDayOfMonth() -> Date {
        let calendar: Calendar = Calendar.current
        var components: DateComponents = calendar.dateComponents([.year, .month, .day], from: self)
        components.setValue(1, for: .day)
        return calendar.date(from: components)!
    }
    
    func firstDayOfYear() -> Date {
        let calendar: Calendar = Calendar.current
        var components: DateComponents = calendar.dateComponents([.year, .month, .day], from: self)
        components.setValue(1, for: .day)
        components.setValue(1, for: .month)
        return calendar.date(from: components)!
    }
}

extension UIScrollView {
    var currentPage: Int {
        return Int((self.contentOffset.x + (0.5 * self.frame.size.width))/self.frame.width) + 1
    }
}

protocol ScrollViewRenewable {
    func renew()
}
