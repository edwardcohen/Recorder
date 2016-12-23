//
//  ContainerViewController.swift
//  VoiceRecorder
//
//  Created by Alex on 02.12.16.
//  Copyright © 2016 CocoaPods. All rights reserved.
//

import UIKit

class ContainerViewController: UIViewController {

    @IBOutlet weak var scrollView: UIScrollView!
    
    var pageControllers: [ScrollViewRenewable] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // 1) Create the three views used in the swipe container view
        let mapController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "MapViewController") as! MapViewController
        mapController.scrollView = self.scrollView
        let recordController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "RecordViewController") as! RecordViewController
        recordController.scrollView = self.scrollView
        let voiceTableController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "VoiceTableViewController") as! VoiceTableViewController
        voiceTableController.scrollView = self.scrollView
        
        pageControllers.append(mapController)
        pageControllers.append(recordController)
        pageControllers.append(voiceTableController)
        
        // 2) Add in each view to the container view hierarchy. Add them in opposite order since the view hieracrhy is a stack
        self.addChildViewController(voiceTableController)
        self.scrollView!.addSubview(voiceTableController.view)
        voiceTableController.didMove(toParentViewController: self)
        
        self.addChildViewController(mapController)
        self.scrollView!.addSubview(mapController.view)
        mapController.didMove(toParentViewController: self)
        
        self.addChildViewController(recordController)
        self.scrollView!.addSubview(recordController.view)
        recordController.didMove(toParentViewController: self)
        
        // 3) Set up the frames of the view controllers to align with eachother inside the container view
        var adminFrame = mapController.view.frame
        adminFrame.origin.x = adminFrame.width
        recordController.view.frame = adminFrame
        
        var bFrame = recordController.view.frame
        bFrame.origin.x = 2 * bFrame.width
        voiceTableController.view.frame = bFrame
        
        
        // 4) Finally set the size of the scroll view that contains the frames
        let scrollWidth = 3 * self.view.frame.width
        let scrollHeight = self.view.frame.size.height
        let somePosition = CGPoint(x: scrollView.frame.size.width, y: 0)
        self.scrollView!.contentSize = CGSize(width: scrollWidth, height: scrollHeight)
        scrollView.setContentOffset(somePosition, animated: false)
        
        scrollView.delegate = self
    }
}

// MARK: UIScrollViewDelegate
extension ContainerViewController: UIScrollViewDelegate {
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        updatePresentingController()
    }
    
    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView)  {
        updatePresentingController()
    }
    
    func updatePresentingController() {
        let currentPage = scrollView.currentPage
        let currentController = pageControllers[currentPage - 1]
        currentController.renew()
        
        if currentPage != 3 {
            let voiceTableController = pageControllers[2] as! VoiceTableViewController
            voiceTableController.collapseCalendarWithoutAnimation()
        }
        
        print("updatePresentingController: \(currentPage)")
    }
}
