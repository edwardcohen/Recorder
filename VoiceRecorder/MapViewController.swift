//
//  MapViewController.swift
//  VoiceRecorder
//
//  Created by Alex on 02.12.16.
//  Copyright © 2016 CocoaPods. All rights reserved.
//

import UIKit

class MapViewController: UIViewController {
    var scrollView: UIScrollView?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.recordBlack
    }
    
    @IBAction func goToList(_ sender: UIButton) {
        if let scrollView = scrollView {
            let somePosition = CGPoint(x: self.view.frame.size.width * 2, y: 0)
            scrollView.setContentOffset(somePosition, animated: true)
        }
    }
    
    @IBAction func goToRecord(_ sender: UIButton) {
        if let scrollView = scrollView {
            let somePosition = CGPoint(x: self.view.frame.size.width, y: 0)
            scrollView.setContentOffset(somePosition, animated: true)
        }
    }
}
