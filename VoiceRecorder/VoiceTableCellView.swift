//
//  TableCellView.swift
//  VoiceRecorder
//
//  Created by developer on 8/4/16.
//  Copyright © 2016 CocoaPods. All rights reserved.
//

import UIKit
import MapKit
import AVFoundation

class VoiceTableCellView: UITableViewCell {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var lengthLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var dayLabel: UILabel!
    @IBOutlet weak var transcription: UILabel!
    @IBOutlet weak var playButton: UIButton!
    
    var tags = [String]()
    
    var sizingCell: TagCellView?
    
    var voiceFileURL : NSURL?
    
    var audioPlayer: AVAudioPlayer?
    
    var timer: Timer?
    
    var session:AVAudioSession?
    
    var isPlaying = false
    
//    @IBOutlet var tagView: UICollectionView!
//    @IBOutlet weak var mapView: MKMapView!
//    @IBOutlet weak var progressView: UIProgressView!
//    @IBOutlet weak var playButton: UIButton!
    
    
//    @IBOutlet weak var detailView: UIView!
    
    var voiceRecord: Voice? {
        didSet {
            if let voiceRecord = voiceRecord {
                
                titleLabel.text = voiceRecord.title
                transcription.text = voiceRecord.transcript
                
                let  minutes = voiceRecord.length.intValue / 60
                let  seconds = voiceRecord.length.intValue % 60
                lengthLabel.text = String(format:"%02i:%02i", minutes, seconds)
                
                let date = voiceRecord.date
                
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "MMM"
                
                var datestring = dateFormatter.string(from: date as Date)
                dateLabel.text = String(datestring.uppercased())
                
                dateFormatter.dateFormat = "dd"
                datestring = dateFormatter.string(from: date as Date)
                dayLabel.text = String(datestring)
                
                tags = voiceRecord.tags!
                
                let annotation = MKPointAnnotation()
                annotation.coordinate = voiceRecord.location.coordinate
                
                voiceFileURL = voiceRecord.audio
            }
        }
    }
    
    func initAudioPlayer() {
        session = AVAudioSession.sharedInstance()
        try! session!.setCategory(AVAudioSessionCategoryPlayback)
        try! session!.setActive(true)
        
        
        if let fileURL = voiceFileURL {
            let audioFileName = fileURL.lastPathComponent
            let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
 
            let soundFileURL = documentDirectory.appendingPathComponent(audioFileName!)
            
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: soundFileURL.path) {
                print("File Avaliable")
                do {
                 //   audioPlayer = nil
                    try audioPlayer = AVAudioPlayer(contentsOf: soundFileURL, fileTypeHint: AVFileTypeAppleM4A)
                    audioPlayer!.prepareToPlay()
                    audioPlayer!.volume = 1.0
                } catch {
                    print("error initializing AVAudioPlayer: \(error)")
                }
            } else {
                print("File Not Avaliable")
            }
            
        }
        
    }
    
    func stopAudioPlayer() {
        if let player = audioPlayer {
            player.stop()
        }
        audioPlayer = nil
        timer?.invalidate()
//        progressView.progress = 0
        isPlaying = false
        playButton.setBackgroundImage(#imageLiteral(resourceName: "play"), for: .normal)
    }
    
    
    @IBAction func playVoiceAction(sender: AnyObject) {
//        if let player = audioPlayer {
//            player.delegate = self
//            if player.isPlaying {
//                player.pause()
//                playButton.setBackgroundImage(#imageLiteral(resourceName: "play"), for: .normal)
//            } else {
//                player.play()
//                startTimer()
//                playButton.setBackgroundImage(#imageLiteral(resourceName: "pause"), for: .normal)
//            }
//        }
        
    }

    func startTimer() {
        timer = Timer(timeInterval: 0.1, target: self, selector: #selector(updateProgress), userInfo: nil, repeats: true)
        RunLoop.main.add(timer!, forMode: RunLoopMode(rawValue: "NSDefaultRunLoopMode"))
    }
    
    func stopTimer() {
        if timer != nil {
            timer!.invalidate()
        }
        timer = nil
    }
    
    func updateProgress() {
        if let player = audioPlayer {
            player.updateMeters()
//            let progress = Float(audioPlayer!.currentTime/audioPlayer!.duration)
//            progressView.progress = progress > 0.98 ? 1: progress
        }
    }
}

//extension VoiceTableCellView: AVAudioPlayerDelegate {
//    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
//        stopAudioPlayer()
//    }
//    
//    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
//        stopTimer()
//    }
//}
