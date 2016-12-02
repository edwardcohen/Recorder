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

class RecordViewController: UIViewController, SFSpeechRecognizerDelegate,NSFetchedResultsControllerDelegate,UIViewControllerTransitioningDelegate, AVAudioRecorderDelegate, CLLocationManagerDelegate  {
    @IBOutlet var recordButton: UIButton!
    @IBOutlet var transTextView: UITextView!
    @IBOutlet var viewCenterRecord: UIView!
//    @IBOutlet var timerLabel: UILabel!
    @IBOutlet var doneButton: UIButton!
    @IBOutlet var titleText: UITextField!
    @IBOutlet var transText: UITextField!
    @IBOutlet var deleteButton: UIButton!
//    @IBOutlet var recordProgress: UIProgressView!
    @IBOutlet var spinner: UIActivityIndicatorView!
//    @IBOutlet var tagView: UICollectionView!
//    @IBOutlet var audioWaveformView: SwiftSiriWaveformView!
    @IBOutlet weak var locationButton: UIButton!
    @IBOutlet weak var listButton: UIButton!
    @IBOutlet var vCircularProgress: KDCircularProgress!
    
    var recordingSession: AVAudioSession!
    var audioRecorder: AVAudioRecorder!
    var locationManager: CLLocationManager!
    var currentLocation: CLLocation?
    var audioFileURL: URL?
    var fetchResultController:NSFetchedResultsController<NSFetchRequestResult>!
    var voiceRecords: [Voice] = []
    var isSpeechEnabled = false
    var isconverstionActive = false
    var tags = ["+"]
    var marks: [Double] = []
    var scrollView: UIScrollView?
    
    ///// Speech Recognizor
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
    
    override func viewDidLoad() {
        view.backgroundColor = UIColor.recordBlack
        viewCenterRecord.layer.cornerRadius = 27.5
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM dd, yyyy"
        let now = dateFormatter.string(from: Date())
        titleText.text = now
        titleText.delegate = self
        transText.delegate = self
        transText.isUserInteractionEnabled = false

        speechRecognizer!.delegate = self  //3
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
        
        spinner.hidesWhenStopped = true
        spinner.center = view.center
        view.addSubview(spinner)
    
        //backgroundImage.isUserInteractionEnabled = true

        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(longPressed))
        longPress.minimumPressDuration = 0.2
        recordButton.addGestureRecognizer(longPress)
        let swipeLeft  = UISwipeGestureRecognizer(target:self ,action: #selector (showCalender) )
        swipeLeft.direction = UISwipeGestureRecognizerDirection.left
        self.view.addGestureRecognizer(swipeLeft)
//        let swipeRight  = UISwipeGestureRecognizer(target:self ,action: #selector (fetchAllRecords) )
//        swipeRight.direction = UISwipeGestureRecognizerDirection.Right
//        
//        self.view.addGestureRecognizer(swipeRight)
        
        self.locationManager = CLLocationManager()
        self.locationManager.delegate = self
        
        getQuickLocationUpdate()
        
        updateUI()
        recordingSession = AVAudioSession.sharedInstance()
        do {
            try recordingSession.setCategory(AVAudioSessionCategoryRecord)
//            try recordingSession.setActive(true)
//           try recordingSession.setActive(true, withOptions:AVAudioSessionSetActiveOptions.NotifyOthersOnDeactivation)
            try recordingSession.setMode(AVAudioSessionModeMeasurement)
            try recordingSession.setActive(true, with:AVAudioSessionSetActiveOptions.notifyOthersOnDeactivation)
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
//        tagView.dataSource = self
//        tagView.delegate = self
        
        let cellNib = UINib(nibName: "TagCellView", bundle: nil)
//        self.tagView.registerNib(cellNib, forCellWithReuseIdentifier: "TagCell")
//        self.tagView.backgroundColor = UIColor.clearColor()
        self.sizingCell = (cellNib.instantiate(withOwner: nil, options: nil) as NSArray).firstObject as! TagCellView?
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
        
//        if audioRecorder != nil {
//            audioRecorder.updateMeters()
//            let normalizedValue:CGFloat = 1.0 - pow(10, CGFloat(audioRecorder.averagePowerForChannel(0))/20)
////            audioWaveformView.amplitude = normalizedValue
//        }
    }
    
    @IBAction func handleDelete() {
        self.view.endEditing(true)
        let deleteAlert = UIAlertController(title: "Delete Record", message: "Are you sure you want to delete this record?", preferredStyle: .alert)
        deleteAlert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        deleteAlert.addAction(UIAlertAction(title: "Yes", style: .default, handler: { action in
            if self.recordState == RecordState.Pause {
                self.tags.removeAll()
                self.tags.append("+")
//                self.tagView.reloadData()
                self.marks.removeAll()
                self.recordState = RecordState.None
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "MMM dd, yyyy"
                let now = dateFormatter.string(from: Date())
                self.transTextView.text = "Transcript goes here..."
                self.titleText.text = now
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
            if recordState == RecordState.Continuous {
                if audioEngine.isRunning {
                    audioEngine.stop()
                    recognitionRequest?.endAudio()
                    isconverstionActive = false
                }
                self.displayLink.isPaused = true
                audioRecorder.pause()
                recordingTimer.invalidate()
                recordState = RecordState.Pause
                updateUI()
            }
        default:
            print("other event at long press")
        }
    }
    
    func doubleTapped() {
        print("double tapped")
        if recordState == RecordState.None {
            startRecording()
            recordState = RecordState.Continuous
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
        case RecordState.Pause:
            marks.append(timerCount)
            audioRecorder.record()
            recordingTimer = Timer.scheduledTimer(timeInterval: 0.01, target: self, selector: #selector(timerUpdate), userInfo: nil, repeats: true)
            timerUpdate()
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
        locationButton.isHidden = isHiddeMain
        listButton.isHidden = isHiddeMain
    }
    
    func updateUI() {
        switch recordState {
        case RecordState.None:
            viewCenterRecord.backgroundColor = UIColor.white
            vCircularProgress.angle = 0
            showedBasicButton(isHiddeMain: false, isHidde: true)
            view.backgroundColor = UIColor.recordBlack
        case RecordState.OneTime, RecordState.Continuous:
            viewCenterRecord.backgroundColor = UIColor(red: 0xFE/255, green: 0x00/255, blue: 0x00/255, alpha: 1.0)
            view.backgroundColor = UIColor.recordRed
            showedBasicButton(isHiddeMain: true, isHidde: true)
        case RecordState.Done:
            viewCenterRecord.backgroundColor = UIColor.white
            view.backgroundColor = UIColor.recordBlack
            vCircularProgress.angle = 0
            showedBasicButton(isHiddeMain: true, isHidde: false)
        case RecordState.Pause:
            viewCenterRecord.backgroundColor = UIColor.white
            view.backgroundColor = UIColor.recordBlack
            showedBasicButton(isHiddeMain: true, isHidde: false)
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
        let settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 12000.0,
            AVNumberOfChannelsKey: 1 as NSNumber,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ] as [String : Any]
        
        do {
            try recordingSession.setCategory(AVAudioSessionCategoryRecord)
//            try recordingSession.setActive(true)
            try recordingSession.setMode(AVAudioSessionModeMeasurement)
            try recordingSession.setActive(true, with:AVAudioSessionSetActiveOptions.notifyOthersOnDeactivation)
            audioRecorder = try AVAudioRecorder(url: audioFileURL!, settings: settings)
            audioRecorder.delegate = self
            audioRecorder.record(forDuration: Constants.MainParameters.durations)
            audioRecorder.prepareToRecord()
            audioRecorder.record()
            timerCount = 0
            recordingTimer = Timer.scheduledTimer(timeInterval: 0.01, target: self, selector: #selector(timerUpdate), userInfo: nil, repeats: true)
            timerUpdate()
        } catch {
            abortRecording()
        }
    }
    
    func SpeechTotextConversion() {
        guard !audioEngine.isRunning else { return }
        
        if let recognitionTask = recognitionTask {
            recognitionTask.cancel()
            self.recognitionTask = nil
        }
//        let audioSession = AVAudioSession.sharedInstance()
//        do {
//            try audioSession.setCategory(AVAudioSessionCategoryRecord)
//            try audioSession.setMode(AVAudioSessionModeMeasurement)
//            try audioSession.setActive(true, withOptions:AVAudioSessionSetActiveOptions.NotifyOthersOnDeactivation)
//            
//        } catch {
//            print("audioSession properties weren't set because of an error.")
//        }

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
        let beforeString = self.transTextView.text
        
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest, resultHandler: { (result, error) in
            var isFinal = false
            if result != nil {
                self.transTextView.text = NSString(format: "%@ %@",beforeString!,(result?.bestTranscription.formattedString)!) as String
                
                let rangeBotm = NSMakeRange(self.transTextView.text.characters.count-1, 1)
            
                self.transTextView.scrollRangeToVisible(rangeBotm)

                isFinal = (result?.isFinal)!
            }
            if error != nil || isFinal {
//                NSRange bottom = NSMakeRange(textView.text.length -1, 1);
//                [textView scrollRangeToVisible:bottom];
//                let rangeBotm = NSMakeRange(self.transTextView.text.characters.count-1, 1)
//                self.transTextView.scrollRangeToVisible(rangeBotm)
                
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
    
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        self.isconverstionActive = available
    }
    
    func stopRecording() {
        audioRecorder.stop()
        recordingTimer.invalidate()
        audioRecorder = nil
    }
    
    func abortRecording() {
        audioRecorder.stop()
        recordingTimer.invalidate()
        showErrorMessage(message: "Recorder did finish recording unsuccessfully")
        audioRecorder = nil
        timerCount = 0
    }
    
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            abortRecording()
            recordState = RecordState.None
            updateUI()
        }
    }
    
    func timerUpdate() {
//        timerLabel.text = String(timerCount)
//        recordProgress.setProgress(Float(timerCount)/60, animated: false)
//        
//        let milliseconds = timerCount * 100;
//        let remaingMilliseconds = Int((milliseconds % 1000) / 10);
//        let seconds = Int((milliseconds / 1000) % 60)
        let progress = 360/60 * Double(timerCount)
//        let angle = 360/60000 * Double(timerCount)
        let angle = progress

        
        print(timerCount)
        print(angle)
        vCircularProgress.angle = angle
//        let imageName = String(format: "progress%f",Float(timerCount))
        
        
//        recordButton.setBackgroundImage(UIImage(named:imageName), forState:  UIControlState.Normal)
        if (timerCount >= 60) {
            audioRecorder.stop()
//            audioRecorder = nil
            vCircularProgress.angle = 360
            recordingTimer.invalidate()
//            recordState = RecordState.Done
//            updateUI()
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
        let title = !((titleText.text?.isEmpty)!) ? titleText.text : now
        let trans = !((transTextView.text?.isEmpty)!) ? transTextView.text : ""
        let length = timerCount - 1 < 0 ? 0 : timerCount - 1
        let tags = self.tags.filter() { $0 != "+" }
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
            updateUI()
        }

        spinner.startAnimating()
        
        var voice:Voice!
        
        if let managedObjectContext = (UIApplication.shared.delegate as? AppDelegate)?.managedObjectContext {
            voice = NSEntityDescription.insertNewObject(forEntityName: "Voice", into: managedObjectContext) as! Voice
            voice.title = title
            voice.tags = tags
            voice.marks = marks
            voice.length = NSNumber(value: length)
            voice.location = location
            voice.date = date
            voice.audio = audio as NSURL
            voice.transcript = trans
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
            self.tags.removeAll()
            self.tags.append("+")
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
}

extension RecordViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return tags.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let tagCell = collectionView.dequeueReusableCell(withReuseIdentifier: "TagCell", for: indexPath) as! TagCellView
        self.configureCell(cell: tagCell, forIndexPath: indexPath as NSIndexPath)
        return tagCell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        self.configureCell(cell: self.sizingCell!, forIndexPath: indexPath as NSIndexPath)
        return self.sizingCell!.systemLayoutSizeFitting(UILayoutFittingCompressedSize)
    }
    
    func configureCell(cell: TagCellView, forIndexPath indexPath: NSIndexPath) {
        cell.tagLabel.text = tags[indexPath.item]
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if tags[indexPath.item] == "+" {
            var tagTextField: UITextField?
            let alertController = UIAlertController(title: "Add Tag", message: nil, preferredStyle: .alert)
            let ok = UIAlertAction(title: "OK", style: .default, handler: { (action) -> Void in
                if let tagText = tagTextField!.text {
                    self.tags.insert(tagText, at: self.tags.count - 1)
//                    self.tagView.reloadData()
                }
            })
            let cancel = UIAlertAction(title: "Cancel", style: .default, handler: nil)
            alertController.addAction(cancel)
            alertController.addAction(ok)
            alertController.addTextField { (textField) -> Void in
                tagTextField = textField
                tagTextField!.placeholder = "Tag"
                tagTextField?.autocapitalizationType = UITextAutocapitalizationType.sentences
            }
            present(alertController, animated: true, completion: nil)
        }
    }
}

// MARK : UITextFieldDelegate
extension RecordViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        titleText.resignFirstResponder()
        transText.resignFirstResponder()
        return true
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        if textField.text! == titleText.text {
        }
    }
}
