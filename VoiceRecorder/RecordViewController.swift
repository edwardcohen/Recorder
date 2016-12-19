//
//  RecordViewController.swift
//  VoiceRecorder
//
//  Created by Eddie Cohen & Jason Toff on 8/2/16.
//  Copyright © 2016 zelig. All rights reserved.
//

import UIKit
import AVFoundation
import CloudKit
import CoreLocation
import CoreData
import Speech
import KDCircularProgress
//import SwiftSiriWaveformView
import SoundWave

class RecordViewController: UIViewController, NSFetchedResultsControllerDelegate,UIViewControllerTransitioningDelegate, AVAudioRecorderDelegate, CLLocationManagerDelegate  {
   
    @IBOutlet var recordButton: UIButton!
    @IBOutlet var transTextView: UITextView!
    @IBOutlet var viewCenterRecord: UIView!
    @IBOutlet var timerLabel: UILabel!
    @IBOutlet var doneButton: UIButton!
    @IBOutlet var titleText: UITextField!
    @IBOutlet var deleteButton: UIButton!
    @IBOutlet var spinner: UIActivityIndicatorView!
    @IBOutlet var tagView: UICollectionView!
//    @IBOutlet var audioWaveformView: SwiftSiriWaveformView!
    @IBOutlet weak var locationButton: UIButton!
    @IBOutlet weak var listButton: UIButton!
    @IBOutlet var vCircularProgress: KDCircularProgress!
    @IBOutlet weak var menuView: UIView!
    
    var recordingSession: AVAudioSession!
    var audioRecorder: AVAudioRecorder!
    var locationManager: CLLocationManager!
    var currentLocation: CLLocation?
    var audioFileURL: URL?
    var audioFileURL1: URL?
    var fetchResultController:NSFetchedResultsController<NSFetchRequestResult>!
    var voiceRecords: [Voice] = []
    var isSpeechEnabled = false
    var isconverstionActive = false
    var tags = ["How was your day?", "Tell me a nice thing you did.", "Tell me a story."] //"+",
    var marks: [Double] = []
    var scrollView: UIScrollView?
    
    // Speech Recognizor
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale.init(identifier: "en-US")) 
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    var sizingCell: TagCellView?
    var recordState = RecordState.None
    var recordingTimer: Timer!
    var timerCount: Double!
    var displayLink: CADisplayLink!
    let customPresentAnimationController = CustomPresentAnimationController()
    var currentTitle = "How was your day?"
    var metering: [Float] = []
    
    private var audioMeteringLevelTimer: Timer?
    
    override func viewDidLoad() {
        view.backgroundColor = .recordBlack
        viewCenterRecord.layer.cornerRadius = 27.5
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM dd, yyyy"
        let now = dateFormatter.string(from: Date())
        titleText.text = now
        transTextView.text = "Transcript goes here..."
        transTextView.textContainerInset = UIEdgeInsets.zero
        transTextView.textContainer.lineFragmentPadding = 0
        
        speechRecognizer!.delegate = self
        SFSpeechRecognizer.requestAuthorization { (authStatus) in
            switch authStatus {
            case .authorized: self.isSpeechEnabled = true
            case .denied: self.isSpeechEnabled = false
            case .restricted: self.isSpeechEnabled = false
            case .notDetermined: self.isSpeechEnabled = false
            }
            self.isconverstionActive = self.isSpeechEnabled
        }

        displayLink = CADisplayLink(target: self, selector: #selector(updateMeters))
        displayLink.add(to: RunLoop.current, forMode: RunLoopMode.commonModes)
        
        timerLabel.isHidden = true
        
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(longPressed))
        longPress.minimumPressDuration = 0.2
//        let singleTap = UITapGestureRecognizer(target: self, action: #selector(singleTapped))
//        singleTap.numberOfTapsRequired = 1
//        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(doubleTapped))
//        doubleTap.numberOfTapsRequired = 2
          recordButton.addGestureRecognizer(longPress)
//        recordButton.addGestureRecognizer(singleTap)
//        recordButton.addGestureRecognizer(doubleTap)
//        
        self.locationManager = CLLocationManager()
        self.locationManager.delegate = self
        
        getQuickLocationUpdate()
        
        updateUI()
        recordingSession = AVAudioSession.sharedInstance()
        do {
            try recordingSession.setCategory(AVAudioSessionCategoryPlayAndRecord, with:.defaultToSpeaker)
            try recordingSession.setActive(true)
            recordingSession.requestRecordPermission() { [unowned self] (allowed: Bool) -> Void in
                DispatchQueue.main.async {
                    if !allowed {
                        self.showErrorMessage(message: "You need to configure Microphone permission")
                    }
                }
            }
        } catch {
            showErrorMessage(message: "Failed to configure AVAudioSession!")
        }
    }
    
    func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "showLastRecord" {
            let destinationController = segue.destination as! VoiceDetailViewController
            let voiceRecord = voiceRecords[0]
            destinationController.voice = voiceRecord
        }
    }
    
    func showCalender() {
        self.performSegue(withIdentifier: "SwipeToCalender", sender: nil)
    }
    
    func updateMeters() {
        if audioRecorder != nil {
            self.audioRecorder!.updateMeters()
            let averagePower = audioRecorder!.averagePower(forChannel: 0)
            let percentage: Float = pow(10, (0.05 * averagePower))
            print("metering - \(percentage)")
            metering.append(percentage)
        }
    }
    
    @IBAction func handleDelete() {
        self.view.endEditing(true)
        let deleteAlert = UIAlertController(title: "Delete Record", message: "Are you sure you want to delete this record?", preferredStyle: .alert)
        deleteAlert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        deleteAlert.addAction(UIAlertAction(title: "Yes", style: .default, handler: { action in
            if self.recordState == RecordState.Pause {
                //self.tags.removeAll()
               // self.tags.append("+")
//                self.tagView.reloadData()
                self.marks.removeAll()
                self.recordState = RecordState.None
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "MMM dd, yyyy"
                let now = dateFormatter.string(from: Date())
                self.transTextView.text = "Transcript goes here..."
                self.titleText.text = now
                self.timerLabel.isHidden = true
                self.updateUI()
            }
        }))
        present(deleteAlert, animated: true, completion: nil)
    }
    
    func showErrorMessage(message: String) {
        let alertController = UIAlertController(title: "Error",
                                                message: message, preferredStyle: UIAlertControllerStyle.alert)
        alertController.addAction(UIAlertAction(title: "OK", style:
            UIAlertActionStyle.default, handler: nil))
        self.present(alertController, animated: true, completion:
            nil)
    }
    
    func longPressed(gesture: UILongPressGestureRecognizer) {

        switch gesture.state {
        case UIGestureRecognizerState.began:
            print("begin long press")
            self.vCircularProgress.isHidden = true
            transTextView.isHidden = false
            UIView.animate(withDuration: 0.4,
                           animations: {
                            self.vCircularProgress.transform = CGAffineTransform(scaleX: 1.25, y: 1.25)
            }, completion: {[unowned self] (_ : Bool) in self.tapticFeedbackOnRecordStateChange()})
            addButtonPulseAnimation()
            
            if recordState == RecordState.None {
                
                startRecording()
                SpeechTotextConversion()
                
                if self.displayLink.isPaused == true {
                    self.displayLink.isPaused = false
                }
                recordState = RecordState.Continuous
                updateUI()
            } else if recordState == RecordState.Pause {
                self.displayLink.isPaused = false
                recordState = RecordState.Continuous
                marks.append(timerCount)
                audioRecorder.record()
                SpeechTotextConversion()
                recordingTimer = Timer.scheduledTimer(timeInterval: 0.01, target: self, selector: #selector(timerUpdate), userInfo: nil, repeats: true)
                timerUpdate()
                recordState = RecordState.Continuous
                updateUI()
            }
            
        case .ended, .cancelled:
            print("end long press")
            self.vCircularProgress.isHidden = false
            tapticFeedbackOnRecordStateChange()
            UIView.animate(withDuration: 0.4,
                           animations: {
                            self.vCircularProgress.transform = CGAffineTransform.identity
            }, completion: nil)
            removeButtonPulseAnimation()
            if recordState == RecordState.Continuous {
                if audioEngine.isRunning {
                    audioEngine.stop()
                    recognitionRequest?.endAudio()
                    isconverstionActive = false
                }
                self.displayLink.isPaused = true
                audioRecorder.pause()
                recordingTimer.invalidate()
                audioMeteringLevelTimer?.invalidate()
                recordState = RecordState.Pause
                updateUI()
            }
        default:
            print("other event at long press")
        }
    }

    func tapticFeedbackOnRecordStateChange() {
        if #available(iOS 10.0, *) {
            let feedbackGenerator = UISelectionFeedbackGenerator()
            feedbackGenerator.prepare()
            feedbackGenerator.selectionChanged()
        } else {
            return
        }
    }
    
    func addButtonPulseAnimation() {
        
            let pulseEffect1 = LFTPulseAnimation(repeatCount: Float.infinity, radius: 40, position: self.recordButton.center)
            self.menuView.layer.insertSublayer(pulseEffect1, below: self.recordButton.layer)
            pulseEffect1.radius = 180
            pulseEffect1.backgroundColor = UIColor.white.cgColor
        
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1) {
            let pulseEffect1 = LFTPulseAnimation(repeatCount: Float.infinity, radius: 40, position: self.recordButton.center)
            self.menuView.layer.insertSublayer(pulseEffect1, below: self.recordButton.layer)
            pulseEffect1.radius = 180
            pulseEffect1.backgroundColor = UIColor.white.cgColor
        }
        
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 2) {
            let pulseEffect1 = LFTPulseAnimation(repeatCount: Float.infinity, radius: 40, position: self.recordButton.center)
            self.menuView.layer.insertSublayer(pulseEffect1, below: self.recordButton.layer)
            pulseEffect1.radius = 180
            pulseEffect1.backgroundColor = UIColor.white.cgColor
        }
    }
    
    func removeButtonPulseAnimation() {
        
        for layer in menuView.layer.sublayers! {
            switch layer {
            case is LFTPulseAnimation:
                layer.removeFromSuperlayer()
            default:
               continue
            }
        }
    }
    
    func doubleTapped() {
        print("double tapped")
        if recordState == RecordState.None {
            startRecording()
            recordState = RecordState.Continuous
            SpeechTotextConversion()
            updateUI()
        }
    }
    
    func singleTapped() {
        print("single tapped")
        var newState: RecordState = recordState
        
        switch recordState {
        case RecordState.Continuous:
            audioRecorder.pause()
            recordingTimer.invalidate()
            newState = RecordState.Pause
            
            if audioEngine.isRunning {
                audioEngine.stop()
                recognitionRequest?.endAudio()
                isconverstionActive = false
            }
            self.displayLink.isPaused = true
            
        case RecordState.Pause:
            marks.append(timerCount)
            audioRecorder.record()
            recordingTimer = Timer.scheduledTimer(timeInterval: 0.01, target: self, selector: #selector(timerUpdate), userInfo: nil, repeats: true)
            timerUpdate()
             SpeechTotextConversion()
            newState = RecordState.Continuous
        default: break
        }

        print("old state=\(recordState), new state=\(newState)")
        recordState = newState
        updateUI()
    }
    
    func showedBasicButton(isHiddeMain: Bool, isHidde: Bool) {
        doneButton.isHidden = isHidde
        deleteButton.isHidden = isHidde
        //locationButton.isHidden = isHiddeMain
        //listButton.isHidden = isHiddeMain
        locationButton.isHidden = true
        listButton.isHidden = true
        tagView.isHidden = isHiddeMain
    }
    
    
    func updateUI() {
        print(recordState)
        switch recordState {
        case RecordState.None:
            viewCenterRecord.backgroundColor = UIColor.white
            vCircularProgress.angle = 0
            showedBasicButton(isHiddeMain: false, isHidde: true)
            UIView.animate(withDuration: 0.4, delay: 0.0, options:[.repeat, .autoreverse], animations: {
                self.view.backgroundColor = UIColor.recordBlack
            }, completion:nil)
            scrollView?.isScrollEnabled = true
            transTextView.isHidden = true
        case RecordState.OneTime, RecordState.Continuous:
            viewCenterRecord.backgroundColor = UIColor(red: 0xFE/255, green: 0x00/255, blue: 0x00/255, alpha: 1.0)
            UIView.animate(withDuration: 0.4, delay: 0.0, options:[], animations: {
                self.view.backgroundColor = UIColor.recordRed
            }, completion:nil)
            showedBasicButton(isHiddeMain: true, isHidde: true)
            transTextView.isHidden = false
        case RecordState.Done:
            viewCenterRecord.backgroundColor = UIColor.white
            UIView.animate(withDuration: 0.4, delay: 0.0, options:[], animations: {
                self.view.backgroundColor = UIColor.recordBlack
            }, completion:nil)
            vCircularProgress.angle = 0
            showedBasicButton(isHiddeMain: true, isHidde: false)
            transTextView.isHidden = true
        case RecordState.Pause:
            viewCenterRecord.backgroundColor = UIColor.white
            UIView.animate(withDuration: 0.4, delay: 0.0, options:[], animations: {
                self.view.backgroundColor = UIColor.recordBlack
            }, completion:nil)
            showedBasicButton(isHiddeMain: true, isHidde: false)
            scrollView?.isScrollEnabled = false
            transTextView.isHidden = false
        }
    }
    
    func getDocumentsDirectoryURL() -> URL {
        let manager = FileManager.default
        let URLs = manager.urls(for: .documentDirectory, in: .userDomainMask)
        return URLs[0]
    }
    
    func startRecording() {
        let filename = NSUUID().uuidString + ".m4a"
        audioFileURL = getDocumentsDirectoryURL().appendingPathComponent(filename)
        timerLabel.isHidden = false
        
        let settings = [
            AVFormatIDKey: NSNumber(value:kAudioFormatAppleLossless),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 2,
            AVEncoderBitRateKey: 12800,
            AVLinearPCMBitDepthKey: 16,
            AVEncoderAudioQualityKey: AVAudioQuality.max.rawValue
        ] as [String : Any]

        do {
            try recordingSession.setCategory(AVAudioSessionCategoryPlayAndRecord, with:.defaultToSpeaker)
            try recordingSession.setActive(true)
            audioRecorder = try AVAudioRecorder(url: audioFileURL!, settings: settings)
            audioRecorder.delegate = self
            audioRecorder.isMeteringEnabled = true
            audioRecorder.record(forDuration: Constants.MainParameters.durations)
            audioRecorder.prepareToRecord()
            audioRecorder.record()
            timerCount = 0
            recordingTimer = Timer.scheduledTimer(timeInterval: 0.01, target: self, selector: #selector(timerUpdate), userInfo: nil, repeats: true)
            timerUpdate()
            metering.removeAll()
            self.audioMeteringLevelTimer = Timer.scheduledTimer(timeInterval: 0.05, target: self, selector: #selector(updateMeters), userInfo: nil, repeats: true)
        } catch {
            abortRecording()
        }
    }
    
    func SpeechTotextConversion() {
        guard !audioEngine.isRunning else { return }
        
        if recordState == RecordState.Pause {
            return
        }

        if let recognitionTask = recognitionTask {
            recognitionTask.cancel()
            self.recognitionTask = nil
        }

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        guard let inputNode = audioEngine.inputNode else {
            fatalError("Audio engine has no input node")
        }
        guard let recognitionRequest = recognitionRequest else {
            fatalError("Unable to create an SFSpeechAudioBufferRecognitionRequest object")
        }
        
        recognitionRequest.shouldReportPartialResults = true
        if self.transTextView.text == "Transcript goes here..." {
            self.transTextView.text = ""
        }
        let beforeString = self.transTextView.text ?? ""
        
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest, resultHandler: { (result, error) in
            var isFinal = false
            if result != nil {
                self.transTextView.text = beforeString + (result?.bestTranscription.formattedString)!
//                    NSString(format: "%@ %@",beforeString!,(result?.bestTranscription.formattedString)!) as String
                
                let rangeBotm = NSMakeRange(self.transTextView.text.characters.count-1, 1)
            
                self.transTextView.scrollRangeToVisible(rangeBotm)

                isFinal = (result?.isFinal)!
            }
            if error != nil || isFinal {
                
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                self.recognitionRequest = nil
                self.recognitionTask = nil
                self.isconverstionActive = true
                
            }
        })

        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat, block: { (buffer, when) in
            self.recognitionRequest?.append(buffer)
        })
        
        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            print("audioEngine couldn't start because of an error.")
        }
    }
    
    func stopRecording() {
        audioRecorder.stop()
        recordingTimer.invalidate()
        audioRecorder = nil
        self.audioMeteringLevelTimer?.invalidate()
    }
    
    func abortRecording() {
        audioRecorder.stop()
        recordingTimer.invalidate()
        self.audioMeteringLevelTimer?.invalidate()
        showErrorMessage(message: "Recorder did finish recording unsuccessfully")
        audioRecorder = nil
        timerCount = 0
        timerLabel.isHidden = true
    }
    
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            abortRecording()
            recordState = RecordState.None
            updateUI()
        }
    }
    
    func timerUpdate() {
         timerLabel.text = String(Int(timerCount))

        let progress = 360/(60) * Double(timerCount)
        let angle = progress

//        print(timerCount)
//        print(angle)
        vCircularProgress.angle = angle * 2
        
        if timerCount >= Constants.MainParameters.durations {
            audioRecorder.stop()
            UIView.animate(withDuration: 0.4, delay: 0.0, options:[], animations: {
                self.view.backgroundColor = UIColor.recordBlack
            }, completion:nil)
            vCircularProgress.angle = 360
            recordingTimer.invalidate()
        }
        
        timerCount = timerCount + 0.01
    }
    
    func getQuickLocationUpdate() {
        // Request location authorization
        if CLLocationManager.locationServicesEnabled() {
            if self.locationManager.responds(to: #selector(CLLocationManager.requestWhenInUseAuthorization)) {
                self.locationManager.requestWhenInUseAuthorization()
            } else {
                self.locationManager.startUpdatingLocation()
            }
        }
//        self.locationManager.requestWhenInUseAuthorization()
        
        // Request a location update
        self.locationManager.requestLocation()
        // Note: requestLocation may timeout and produce an error if authorization has not yet been granted by the user
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        print("Got current location.")
        currentLocation = locations.last
        locationManager.stopUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Error while updating location " + error.localizedDescription)
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .notDetermined: locationManager.requestAlwaysAuthorization()
        case .authorizedWhenInUse: locationManager.startUpdatingLocation()
        case .authorizedAlways: locationManager.startUpdatingLocation()
        default: break
        }
    }
//    @IBAction func recordTouchDown() {
//
//        
////        if recordState == RecordState.Continuous {
////            self.displayLink.paused = true
////            audioRecorder.pause()
////            recordingTimer.invalidate()
////            recordState = RecordState.Pause
////            updateUI()
////        }
//
//
//    }
//    @IBAction func recordTouchUp() {
//        
////        if recordState == RecordState.None {
////            startRecording()
////            if self.displayLink.paused == true {
////                self.displayLink.paused = false
////            }
////            //                recordState = RecordState.OneTime
////            recordState = RecordState.Continuous
////            updateUI()
////        } else if recordState == RecordState.Pause {
////            self.displayLink.paused = false
////            marks.append(timerCount)
////            audioRecorder.record()
////            recordingTimer = NSTimer.scheduledTimerWithTimeInterval(1.0, target: self, selector: #selector(timerUpdate), userInfo: nil, repeats: true)
////            timerUpdate()
////            recordState = RecordState.Continuous
////            updateUI()
////        }
//        
//        
//    }
    @IBAction func doneTapped() {
        self.view.endEditing(true)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM dd, yyyy"
        let now = dateFormatter.string(from: Date())
        if transTextView.text == "Transcript goes here..." {
            transTextView.text = ""
        }

        let trans = !((transTextView.text?.isEmpty)!) ? transTextView.text : "<No transcription>"
        let length = timerCount - 1 < 0 ? 0 : timerCount - 1
//            try? self.viewModel.startPlaying()
       // let tags = self.tags.filter() { $0 != "+" }
        let location = currentLocation != nil ? currentLocation! : CLLocation()
        let date = NSDate()
        let marks = self.marks
        let audio = audioFileURL!
        
//        let voice = Voice(title: title,transcript :trans ,length: length, date: date, tags: tags, location: location, marks: marks, audio: audio)
//        saveRecordToCloud(voice)
        if recordState == RecordState.Pause {
//            self.displayLink.invalidate()
            stopRecording()
            recordState = RecordState.Done
            timerLabel.isHidden = true
            updateUI()
        }

        spinner.startAnimating()
        
        var voice: Voice!
        
        if let managedObjectContext = (UIApplication.shared.delegate as? AppDelegate)?.managedObjectContext {
            voice = NSEntityDescription.insertNewObject(forEntityName: "Voice", into: managedObjectContext) as! Voice
            voice.title = currentTitle
            voice.tags = tags
            voice.marks = marks
            voice.length = NSNumber(value: length)
            voice.location = location
            voice.date = date
            voice.audio = audio as NSURL
            voice.transcript = trans
            voice.metering = metering
//            saveRecordToCloud(voice)

            do {
                try managedObjectContext.save()
                self.spinner.stopAnimating()
                print("Successed in saving records to the core data")
            } catch {
                print("Failed to save record to the core data: \(error)")
                return
            }
        }
        
        if recordState == RecordState.Done {
//            self.tags.removeAll()
//            self.tags.append("+")
//            tagView.reloadData()
            self.marks.removeAll()
            recordState = RecordState.None
            updateUI()
            titleText.text = now
            transTextView.text = "Transcript goes here..."
            self.displayLink.isPaused = false
        }
        
        if let scrollView = scrollView {
            let somePosition = CGPoint(x: self.view.frame.size.width * 2, y: 0)
            let voiceTable = self
//                self.superclass.childViewControllers[2] as! VoiceTableViewController
            voiceTable.viewWillAppear(true)
            scrollView.setContentOffset(somePosition, animated: true)
        }
    }
    
    // MARK: - CloudKit Methods
    func fetchAllRecords() {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName:"Voice")
        let sortDescriptor = NSSortDescriptor(key: "date", ascending: false)
        fetchRequest.sortDescriptors = [sortDescriptor]
        
        if let managedObjectContext = (UIApplication.shared.delegate as? AppDelegate)?.managedObjectContext {
            fetchResultController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: managedObjectContext, sectionNameKeyPath: nil, cacheName: nil)
            fetchResultController.delegate = self
            
            do {
                try fetchResultController.performFetch()
                voiceRecords = fetchResultController.fetchedObjects as! [Voice]
                self.performSegue(withIdentifier: "showLastRecord", sender: nil)
                
                print("Retrived data from core data")
//                completionHandler(true)
            } catch {
                print("Failed to get data from core data - \(error)")
//                completionHandler(false)
            }
        }
    }
    
    func saveRecordToCloud(voice: Voice) -> Void {
        spinner.startAnimating()
        // Prepare the record to save
        let record = CKRecord(recordType: "Voice")
        record.setValue(voice.title, forKey: "title")
        record.setValue(voice.length, forKey: "length")
        record.setValue(voice.tags, forKey: "tags")
        record.setValue(voice.location, forKey: "location")
        record.setValue(voice.marks, forKey: "marks")
        record.setValue(voice.date, forKey: "date")
        record.setValue(voice.transcript, forKey: "transcript")
        //TODO: - add metering
        // Create audio asset for upload
        let audioAsset = CKAsset(fileURL: voice.audio as URL)
        record.setValue(audioAsset, forKey: "audio")
        
        // Get the Public iCloud Database
        let publicDatabase = CKContainer.default().publicCloudDatabase
        let saveRecordsOperation = CKModifyRecordsOperation()
        saveRecordsOperation.recordsToSave = [record]
        saveRecordsOperation.savePolicy = .allKeys
        saveRecordsOperation.queuePriority = .veryHigh

        saveRecordsOperation.modifyRecordsCompletionBlock = { savedRecords, deletedRecordIDs, error in
            if (error == nil) {
                // Remove temp file
                do {
                    try FileManager.default.removeItem(atPath: voice.audio.path!)
                    print("Saved record to the cloud.")
                    
                    OperationQueue.main.addOperation() {
                        self.spinner.stopAnimating()
                        self.performSegue(withIdentifier: "doneRecording", sender: self)
                    }
                } catch {
                    print("Failed to delete temparary file.")
                }
            } else {
                print("Failed to save record to the cloud: \(error)")
            }
        }

        publicDatabase.add(saveRecordsOperation)
    }
    
    // MARK : Scroll to next screen
    @IBAction func goToMap(_ sender: UIButton) {
        if let scrollView = scrollView {
            scrollView.setContentOffset(CGPoint.zero, animated: true)
        }
    }
    
    @IBAction func goToList(_ sender: UIButton) {
        if let scrollView = scrollView {
            let somePosition = CGPoint(x: self.view.frame.size.width * 2, y: 0)
            scrollView.setContentOffset(somePosition, animated: true)
        }
    }
    
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        var visibleRect = CGRect()
        visibleRect.origin = tagView.contentOffset
        visibleRect.size = tagView.bounds.size
        let visiblePoint = CGPoint(x: visibleRect.midX, y: visibleRect.midY)
        let visibleIndexPath: IndexPath = tagView.indexPathForItem(at: visiblePoint)!
        currentTitle = tags[visibleIndexPath.row]
//        print(visibleIndexPath)
    }
}

extension RecordViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return tags.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let tagCell = collectionView.dequeueReusableCell(withReuseIdentifier: "TagCell", for: indexPath) as! TagCellView
        tagCell.tagLabel.text = tags[indexPath.item]
        tagCell.tagLabel.adjustsFontSizeToFitWidth = true
        tagCell.tagLabel.sizeToFit()
        return tagCell
    }
}

extension RecordViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
//        if tags[indexPath.item] == "+" {
//            var tagTextField: UITextField?
//            let alertController = UIAlertController(title: "Add Tag", message: nil, preferredStyle: .alert)
//            let ok = UIAlertAction(title: "OK", style: .default, handler: { (action) -> Void in
//                if let tagText = tagTextField!.text {
//                    self.tags.insert(tagText, at: self.tags.count - 1)
//                    //                    self.tagView.reloadData()
//                }
//            })
//            let cancel = UIAlertAction(title: "Cancel", style: .default, handler: nil)
//            alertController.addAction(cancel)
//            alertController.addAction(ok)
//            alertController.addTextField { (textField) -> Void in
//                tagTextField = textField
//                tagTextField!.placeholder = "Tag"
//                tagTextField?.autocapitalizationType = UITextAutocapitalizationType.sentences
//            }
//            present(alertController, animated: true, completion: nil)
//        }
    }
}

extension RecordViewController: ScrollViewRenewable {
    func renew() {
        updateUI()
    }
}

extension RecordViewController: SFSpeechRecognizerDelegate {
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        self.isconverstionActive = available
    }
}
