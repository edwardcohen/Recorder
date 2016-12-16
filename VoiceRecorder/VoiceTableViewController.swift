//
//  VoiceTableViewController.swift
//  VoiceRecorder
//
//  Created by Eddie Cohen & Jason Toff on 8/2/16.
//  Copyright © 2016 zelig. All rights reserved.
//

import JTAppleCalendar
import CloudKit
import UIKit
import CoreData
import MapKit
import AVFoundation

class VoiceTableViewController: UIViewController {
    
    var voiceRecords: [Voice] = []
    var originRecords: [Voice] = []
    var filteredRecords: [Voice] = []
    var fetchResultController:NSFetchedResultsController<NSFetchRequestResult>!
    var selectedDate: Date?
    var selectedMonth : Int?
    var selectedYear : Int?
    var taptoHidekeyBoard : UITapGestureRecognizer?
    var scrollView: UIScrollView?
    var searchArray: [Voice] = []
    var audioPlayer: AVAudioPlayer?
    var session: AVAudioSession?
    let formatter = DateFormatter()
    var calendar  = Calendar(identifier: Calendar.Identifier.gregorian)
    var tags = [String]()
    var selectedCellIndexPath:IndexPath?
    
    @IBOutlet weak var buttonsView: UIView!
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var monthLabel: UILabel!
    @IBOutlet weak var collapseCalendarButton: UIButton!
    @IBOutlet weak var calendarView: JTAppleCalendarView!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var spinner: UIActivityIndicatorView!
    @IBOutlet weak var calendarViewHeightContraint: NSLayoutConstraint!
    @IBOutlet weak var weekDaysStackView: UIStackView!
    
    let viewModel = ViewModel()
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        self.view.setNeedsLayout()
        self.view.bringSubview(toFront: buttonsView)
        
        view.backgroundColor = UIColor.recordBlack
        searchBar.delegate = self
        
        let textFieldInsideSearchBar = searchBar.value(forKey: "searchField") as? UITextField
        textFieldInsideSearchBar?.textColor = UIColor.white
        let font = UIFont(name: "SFUIDisplay-Regular", size: 14)
        textFieldInsideSearchBar?.font = font
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(onClickMonthLabel))
        monthLabel.addGestureRecognizer(tap)
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.estimatedRowHeight = 65
        tableView.rowHeight = UITableViewAutomaticDimension
        view.backgroundColor = .recordBlack

        taptoHidekeyBoard = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        taptoHidekeyBoard?.numberOfTapsRequired = 1
    }
    
    func handleTap(sender: UITapGestureRecognizer? = nil) {
        searchBar.resignFirstResponder()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        self.tableView.rowHeight = UITableViewAutomaticDimension
        spinner.hidesWhenStopped = true
        spinner.center = view.center
        view.addSubview(spinner)
        tableView.backgroundColor = .clear
        
        renew()
//        collapseCalendarWithoutAnimation()
    }
    
    func onClickMonthLabel() {
        collapseCalendar()
        let monthName = DateFormatter().monthSymbols[(selectedMonth!-1) % 12]
        monthLabel.text = monthName
        
        let components = calendar.dateComponents([.year, .month], from: selectedDate!)
        let startOfMonth = calendar.date(from: components)!
        
        var comps2 = DateComponents()
        comps2.month = 1
        comps2.day = -1
        let endOfMonth = calendar.date(byAdding: comps2, to: startOfMonth)
        
        calendarView.selectDates([])
        
        let predicate = NSPredicate(format: "(date >= %@) AND (date <=%@)", argumentArray: [startOfMonth, endOfMonth!])
        self.fetchResultController.fetchRequest.predicate = predicate
        do {
            try self.fetchResultController.performFetch()
            voiceRecords = fetchResultController.fetchedObjects as! [Voice]
            self.tableView.reloadData()
        } catch {
            let fetchError = error as NSError
            print("\(fetchError), \(fetchError.userInfo)")
        }
    }
    
    //MARK: Actions
    @IBAction func collapseCallendar(_ sender: UIButton) {
        collapseCalendar()
    }
    
    func collapseCalendar() {
        if self.calendarViewHeightContraint.constant == 0 {
            collapseCalendarButton.setImage(UIImage(named:"icon_minus"), for: UIControlState.normal)
            UIView.animate(withDuration: 0.5, animations: {
                self.weekDaysStackView.isHidden = false
                self.calendarViewHeightContraint.constant = 200
                self.view.layoutIfNeeded()
            })
        } else {
            collapseCalendarButton.setImage(UIImage(named:"icon_plus"), for: UIControlState.normal)
            UIView.animate(withDuration: 0.5, animations: {
                self.weekDaysStackView.isHidden = true
                self.calendarViewHeightContraint.constant = 0
                self.view.layoutIfNeeded()
            })
        }
    }
    
    @IBAction func deleteRecordButtonClicked(_ sender: UIButton) {
        
        let deleteAlert = UIAlertController(title: "Delete Record", message: "Are you sure you want to delete this record?", preferredStyle: .alert)
        deleteAlert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        deleteAlert.addAction(UIAlertAction(title: "Yes", style: .default, handler: {
            [unowned self] action in
            
            let managedContext = (UIApplication.shared.delegate as! AppDelegate).managedObjectContext
            guard let selectedCellIndexPath = self.selectedCellIndexPath else {return}
            
            
            let voiceRecord = self.searchBar.text != "" ? self.filteredRecords[selectedCellIndexPath.row] : self.voiceRecords[selectedCellIndexPath.row]
            
            if self.searchBar.text != "" {
                self.filteredRecords.remove(at: selectedCellIndexPath.row)
                if let deleteIndex = self.voiceRecords.index(of: voiceRecord) {
                    self.voiceRecords.remove(at: deleteIndex)
                }
            } else {
                self.voiceRecords.remove(at: selectedCellIndexPath.row)
                if let deleteIndex = self.filteredRecords.index(of: voiceRecord) {
                    self.filteredRecords.remove(at: deleteIndex)
                }
            }
            
            self.tableView.deleteRows(at: [selectedCellIndexPath], with: UITableViewRowAnimation.fade)
            self.selectedCellIndexPath = nil
            managedContext.delete(voiceRecord)
            
            do {
                try managedContext.save()
            } catch let error as NSError {
                print("Error While Deleting Note: \(error.userInfo)")
            }
        }))
        
        present(deleteAlert, animated: true, completion: nil)
        
    }
    
    @IBAction func shareRecordButtonClicked(_ sender: UIButton) {
        
        guard let selectedCellIndexPath = selectedCellIndexPath else {return}
        let voiceRecord = searchBar.text != "" ? filteredRecords[selectedCellIndexPath.row] : voiceRecords[selectedCellIndexPath.row]
        
        if let transcript = voiceRecord.transcript {
            
            let activityViewController = UIActivityViewController(activityItems: [transcript], applicationActivities: nil)
            activityViewController.excludedActivityTypes = [UIActivityType.airDrop]
            self.present(activityViewController, animated: true) {}
        }
    }
    
    @IBAction func playButtonPressed(_ sender: UIButton) {
        
        guard
            let selectedCellIndexPath = selectedCellIndexPath,
            let cell = tableView.cellForRow(at: selectedCellIndexPath) as? VoiceTableCellView,
            let player = audioPlayer
            else {return}
        player.delegate = self
        if player.isPlaying {
            player.pause()
            cell.waves.pause()
            cell.playButton.setImage(#imageLiteral(resourceName: "play") , for: UIControlState.normal)
        } else {
            let data = voiceRecords[selectedCellIndexPath.row]
            cell.waves.audioVisualizationMode = .read
            cell.waves.meteringLevelsArray = data.metering
            cell.waves.play(for: TimeInterval(data.length.floatValue + 0.5))
            player.play()
            cell.playButton.setImage(#imageLiteral(resourceName: "pause") , for: UIControlState.normal)
        }
    }
    
    struct SoundRecord {
        var audioFilePathLocal: URL?
        var meteringLevels: [Float]?
    }
    
    @IBAction func rewindForwardButtonPressed(_ sender: UIButton) {
        rewindCurrentFile(timeInterval: 1)
    }
    
    @IBAction func rewindBackwardButtonPressed(_ sender: UIButton) {
        rewindCurrentFile(timeInterval: -1)
    }
    
    func setupViewsOfCalendar(startDate: Date, endDate: Date) {
        let month = Calendar.current.component(Calendar.Component.month, from: endDate)
        selectedMonth = month
        let year = Calendar.current.component(Calendar.Component.year, from: endDate)
        selectedYear = year
        var day = Calendar.current.component(Calendar.Component.day, from: selectedDate!)
        if month == 2 {
            if day == 31 || day == 30 || day ==  29 {
                if year % 4 == 0 {
                    day = 29
                }else
                {
                    day = 28
                }
            }
        }else if month == 4 || month == 6 || month == 9 || month == 11 {
            
            if day == 31 {
                day = 30
            }
        }
        
        let dateMakerFormatter = DateFormatter()
        dateMakerFormatter.dateFormat = "yyyy/MM/dd"
        let keptDate = dateMakerFormatter.date(from: String(format: "%i/%i/%i",year,month,day))!
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM dd, yyyy"
        let selected = dateFormatter.string(from: keptDate)
        monthLabel.text = selected
        calendarView.selectDates([keptDate])
    }
    
    //    func getRecordsFromCloud(completionHandler: (Bool) -> Void) {
    //        // Fetch data using Operational API
    //        let cloudContainer = CKContainer.defaultContainer()
    //        let publicDatabase = cloudContainer.publicCloudDatabase
    //        let predicate = NSPredicate(value: true)
    //        let query = CKQuery(recordType: "Voice", predicate: predicate)
    //        query.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
    //
    //        // Create the query operation with the query
    //        let queryOperation = CKQueryOperation(query: query)
    //        queryOperation.desiredKeys = ["title", "length", "date", "location", "tags", "marks"]
    //        queryOperation.queuePriority = .VeryHigh
    //        queryOperation.resultsLimit = 50
    //        queryOperation.recordFetchedBlock = { (record:CKRecord!) -> Void in
    //            if let voiceRecord = record {
    //                self.voiceRecords.append(voiceRecord)
    //            }
    //        }
    
    //        queryOperation.queryCompletionBlock = { (cursor:CKQueryCursor?, error:NSError?) -> Void in
    //            if (error != nil) {
    //                print("Failed to get data from iCloud - \(error!.localizedDescription)")
    //                completionHandler(false)
    //                return
    //            }
    //
    //            print("Retrieved data from iCloud")
    //            completionHandler(true)
    //        }
    
    // Execute the query
    //        publicDatabase.addOperation(queryOperation)
    //    }
    
    func getVoiceRecordsFromCoreData(completionHandler: (Bool) -> Void) {
        // Load the voices from database
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName:"Voice")
        let sortDescriptor = NSSortDescriptor(key: "date", ascending: false)
        fetchRequest.sortDescriptors = [sortDescriptor]
        
        if let managedObjectContext = (UIApplication.shared.delegate as? AppDelegate)?.managedObjectContext {
            fetchResultController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: managedObjectContext, sectionNameKeyPath: nil, cacheName: nil)
            fetchResultController.delegate = self
            
            do {
                try fetchResultController.performFetch()
                voiceRecords = fetchResultController.fetchedObjects as! [Voice]
                searchArray = voiceRecords
                print("Retrived data from core data")
                completionHandler(true)
            } catch {
                print("Failed to get data from core data - \(error)")
                completionHandler(false)
            }
        }
    }
    
    func getTagsFromRecords() {
        var tags = [String]()
        for voiceRecord in voiceRecords {
            if let recordTags = voiceRecord.tags {
                for recordTag in recordTags {
                    tags.append(recordTag)
                }
            }
        }
        print(tags)
        
        // Sort by frequency
        var tagFrequencies = [String: Int]()
        for tag in tags {
            if tagFrequencies[tag] == nil {
                tagFrequencies[tag] = 1
            } else {
                tagFrequencies[tag] = tagFrequencies[tag]! + 1
            }
        }
        print(tagFrequencies)
        
        var sortedTags = Array(tagFrequencies.keys)
        sortedTags.sort(by: { tagFrequencies[$0]! > tagFrequencies[$1]! })
        print(sortedTags)
        
        self.tags = sortedTags
    }
    
    // MARK: - Navigation
    func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "showVoiceDetail" {
            if let indexPath = tableView.indexPathForSelectedRow {
                let destinationController = segue.destination as! VoiceDetailViewController
                let voiceRecord = voiceRecords[indexPath.row]
                destinationController.voice = voiceRecord
                destinationController.previousView = "tble"
            }
        }
    }
    
    func getDocumentsDirectoryURL() -> URL {
        let manager = FileManager.default
        let URLs = manager.urls(for: .documentDirectory, in: .userDomainMask)
        return URLs[0]
    }
    
    //    func getAudioFromCloud(voiceRecord: CKRecord, completionHandler: (Bool, NSURL?) -> Void) {
    //        // Fetch Audio from Cloud in background
    //        let publicDatabase = CKContainer.defaultContainer().publicCloudDatabase
    //        let fetchRecordsImageOperation = CKFetchRecordsOperation(recordIDs:
    //            [voiceRecord.recordID])
    //        fetchRecordsImageOperation.desiredKeys = ["audio"]
    //        fetchRecordsImageOperation.queuePriority = .VeryHigh
    //        fetchRecordsImageOperation.perRecordCompletionBlock = {(record:CKRecord?,
    //            recordID:CKRecordID?, error:NSError?) -> Void in
    //            if (error != nil) {
    //                print("Failed to get voice audio: \(error!.localizedDescription)")
    //                completionHandler(false, nil)
    //                return
    //            }
    //            if let voiceRecord = record {
    //                NSOperationQueue.mainQueue().addOperationWithBlock() {
    //                    if let audioAsset = voiceRecord.objectForKey("audio") as? CKAsset {
    //                        completionHandler(true, audioAsset.fileURL)
    //                    }
    //                }
    //            } else {
    //                completionHandler(false, nil)
    //            }
    //
    //        }
    //        publicDatabase.addOperation(fetchRecordsImageOperation)
    //    }
    
    func getAudioFromCoreData(voiceRecord: Voice, completionHandler: (Bool, NSURL?) -> Void) {
        // Fetch Audio from Core Data in background
        if voiceRecord.audio.absoluteString != "" {
            completionHandler(true, voiceRecord.audio)
        } else {
            print("Failed to get voice audio")
            completionHandler(false, nil)
        }
    }
    
    // MARK: Drawer Content View Controller Delegate
    
    func collapsedDrawerHeight() -> CGFloat
    {
        return 38.0
    }
    
    func partialRevealDrawerHeight() -> CGFloat
    {
        return 300.0
    }
    
    
    @IBAction func goToLocation(_ sender: UIButton) {
        if let scrollView = scrollView {
            scrollView.setContentOffset(CGPoint.zero, animated: true)
        }
    }
    
    @IBAction func goToRecord(_ sender: UIButton) {
        if let scrollView = scrollView {
            let somePosition = CGPoint(x: self.view.frame.size.width, y: 0)
            scrollView.setContentOffset(somePosition, animated: true)
        }
    }
}

func delayRunOnMainThread(delay:Double, closure: @escaping ()->()) {
    
    DispatchQueue.main.asyncAfter(
        deadline: DispatchTime.now() +
            Double(Int64(delay * Double(NSEC_PER_SEC))) /
            Double(NSEC_PER_SEC), execute: closure)
}

// MARK: -NSFetchedResultsControllerDelegate
extension VoiceTableViewController: NSFetchedResultsControllerDelegate {
    
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.beginUpdates()
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        
        self.calendarView.reloadData()
        
        //        switch type {
        //        case .insert:
        //            self.calendarView.reloadData()
        //            //if let _newIndexPath = newIndexPath {
        //                //tableView.insertRows(at: [_newIndexPath], with: .fade)
        //            //}
        //        case .delete:
        //            self.calendarView.reloadData()
        //            //if let _indexPath = indexPath {
        //                //tableView.deleteRows(at: [_indexPath], with: .fade)
        //
        //                //self.voiceRecords.remove(at: _indexPath.row)
        //               // calendarView.reloadData()
        //            }
        //        case .update:
        //        self.calendarView.reloadData()
        //            //if let _indexPath = indexPath {
        //                //tableView.reloadRows(at: [_indexPath], with: .fade)
        //            //}
        //
        //        default:
        //            self.calendarView.reloadData()
        //            //tableView.reloadData()
        //        }
        
        //        voiceRecords = controller.fetchedObjects as! [Voice]
        //        originRecords = voiceRecords
        //        self.getTagsFromRecords()
        //        tagView.reloadData()
    }
    
    func controller(controller: NSFetchedResultsController<NSFetchRequestResult>, didChangeSection sectionInfo: NSFetchedResultsSectionInfo, atIndex sectionIndex: Int, forChangeType type: NSFetchedResultsChangeType) {
        switch type {
        case .insert:
            let sectionIndexSet = NSIndexSet(index: sectionIndex)
            self.tableView.insertSections(sectionIndexSet as IndexSet, with: .fade)
        case .delete:
            let sectionIndexSet = NSIndexSet(index: sectionIndex)
            self.tableView.deleteSections(sectionIndexSet as IndexSet, with: .fade)
            
        default:
            tableView.reloadData()
        }
        voiceRecords = controller.fetchedObjects as! [Voice]
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.endUpdates()
    }
    
}

// MARK: JTAppleCalendarViewDataSource
extension VoiceTableViewController: JTAppleCalendarViewDataSource {
    
    func configureCalendar(_ calendar: JTAppleCalendarView) -> ConfigurationParameters {
        let startDate = Date().firstDayOfYear()
        let endDate = Date()
        let parameters = ConfigurationParameters(startDate: startDate,
                                                 endDate: endDate,
                                                 numberOfRows: 6,
                                                 calendar: Calendar.current,
                                                 generateInDates: .forAllMonths,
                                                 generateOutDates: .tillEndOfGrid,
                                                 firstDayOfWeek: .sunday)
        
        return parameters
    }
}

// MARK: JTAppleCalendarViewDelegate
extension VoiceTableViewController: JTAppleCalendarViewDelegate {
    
    func calendar(_ calendar: JTAppleCalendarView, willDisplayCell cell: JTAppleDayCellView, date: Date, cellState: CellState) {
        var hasVoice = false
        //        if let _ = voiceRecords.indexOf({
        //            NSCalendar.currentCalendar().compareDate(($0.date), toDate: date, toUnitGranularity: .Day)==NSComparisonResult.OrderedSame}) {
        //            hasVoice = true
        //        }
        let curCalendar = Calendar.current
        
        let startOfDay = curCalendar.startOfDay(for: date)
        
        var components = DateComponents()
        components.hour = 23
        components.minute = 59
        components.second = 59
        let endOfDay = curCalendar.date(byAdding: components, to: startOfDay)
        
        let predicate = NSPredicate(format: "(date >= %@) AND (date <=%@)", argumentArray: [startOfDay, endOfDay!])
        self.fetchResultController.fetchRequest.predicate = predicate
        do {
            let count = try self.fetchResultController.managedObjectContext.count(for: self.fetchResultController.fetchRequest)
            if count > 0 {
                hasVoice = true
            }
        } catch let error as NSError {
            print("Error: \(error.localizedDescription)")
        }
        
        (cell as? CalendarCellView)?.hasVoice = hasVoice
        
        (cell as? CalendarCellView)?.setupCellBeforeDisplay(cellState: cellState, date: date)
    }
    
    func calendar(_ calendar: JTAppleCalendarView, didDeselectDate date: Date, cell: JTAppleDayCellView?, cellState: CellState) {
        (cell as? CalendarCellView)?.cellSelectionChanged(cellState: cellState)
    }
    
    func calendar(_ calendar: JTAppleCalendarView, didSelectDate date: Date, cell: JTAppleDayCellView?, cellState: CellState) {
        
        (cell as? CalendarCellView)?.cellSelectionChanged(cellState: cellState)
        
        let curCalendar = Calendar.current
        let startOfDay = curCalendar.startOfDay(for: date)
        
        var components = DateComponents()
        components.hour = 23
        components.minute = 59
        components.second = 59
        let endOfDay = curCalendar.date(byAdding: components, to: startOfDay)
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM dd, yyyy"
        let selected = dateFormatter.string(from: date)
        monthLabel.text = selected
        selectedDate = endOfDay
        
        let predicate = NSPredicate(format: "(date >= %@) AND (date <=%@)", argumentArray: [startOfDay, endOfDay!])
        
        self.fetchResultController.fetchRequest.predicate = predicate
        do {
            try self.fetchResultController.performFetch()
            voiceRecords = fetchResultController.fetchedObjects as! [Voice]
            if searchBar.text != "" {
                filterContentForSearchText(searchText: searchBar.text!)
            } else {
                self.tableView.reloadData()
            }
        } catch {
            let fetchError = error as NSError
            print("\(fetchError), \(fetchError.userInfo)")
        }
    }
    
    func calendar(_ calendar: JTAppleCalendarView, willResetCell cell: JTAppleDayCellView) {
        (cell as? CalendarCellView)?.selectedView.isHidden = true
    }
    
    func calendar(_ calendar: JTAppleCalendarView, didScrollToDateSegmentWith visibleDates: DateSegmentInfo) {
        setupViewsOfCalendar(startDate: visibleDates.monthDates.first!, endDate: visibleDates.monthDates.last!)
    }
}


// MARK: UITableViewDataSource
extension VoiceTableViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if searchBar.text != "" {
            return filteredRecords.count
        }
        return voiceRecords.count
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "VoiceTableCell", for: indexPath) as! VoiceTableCellView
        
        let voiceRecord: Voice
        if searchBar.text != "" {
            voiceRecord = filteredRecords[indexPath.row]
        } else {
            voiceRecord = voiceRecords[indexPath.row]
        }
        let heightText = Functions.getStringHeight(voiceRecord.transcript, font: UIFont(name: "SFUIDisplay-Regular", size: 13)!, width: self.view.frame.width - 50)
        //think about this for others devices
        cell.topWavesConstrains.constant = 79.0 + heightText - 25
        cell.topPlayerConstrains.constant = 141.5 + heightText - 25
        
        cell.voiceRecord = voiceRecord
        cell.backgroundColor = .clear
        cell.waves.meteringLevelsArray = voiceRecord.metering
        cell.waves.meteringLevels = cell.waves.scaleSoundDataToFitScreen()
        cell.waves.audioVisualizationMode = .read
        cell.waves.meteringLevelBarWidth = 1.0
        cell.waves.gradientStartColor = UIColor.hex(hex: "#686868")
        cell.waves.gradientEndColor = .white
        
        let backgroundView = UIView()
        backgroundView.backgroundColor = .clear
        cell.selectedBackgroundView = backgroundView
        
        return cell
    }
}

// MARK: UITableViewDelegate
extension VoiceTableViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if selectedCellIndexPath == indexPath {
            return UITableViewAutomaticDimension
        }
        return 65
    }
    
    private func tableView(tableView: UITableView, estimatedHeightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        return UITableViewAutomaticDimension
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let array = tableView.indexPathsForSelectedRows ?? []
        for index in array {
            print(index.row)
        }
        if let cell = tableView.cellForRow(at: indexPath) as? VoiceTableCellView {
            if selectedCellIndexPath == indexPath {
                selectedCellIndexPath = nil
                audioPlayer?.stop()
            } else {
                selectedCellIndexPath = indexPath
                initAudioPlayer()
                cell.playButton.setImage(#imageLiteral(resourceName: "play") , for: UIControlState.normal)
            }
            
            tableView.beginUpdates()
            tableView.deselectRow(at: indexPath, animated: true)
            tableView.endUpdates()
    //        self.tableView.reloadData()
        }
    }
}

// MARK: UISearchBarDelegate
extension VoiceTableViewController: UISearchBarDelegate {
    
    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        self.view .addGestureRecognizer(taptoHidekeyBoard!)
        if self.calendarViewHeightContraint.constant > 0 {
            collapseCalendarButton.setImage(UIImage(named:"icon_plus"), for: UIControlState.normal)
            UIView.animate(withDuration: 0.5, animations: {
                self.weekDaysStackView.isHidden = true
                self.calendarViewHeightContraint.constant = 0
                self.view.layoutIfNeeded()
            })
        }
    }
    
    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        self.view.removeGestureRecognizer(taptoHidekeyBoard!)
        if self.calendarViewHeightContraint.constant == 0 {
            collapseCalendarButton.setImage(UIImage(named:"icon_plus"), for: UIControlState.normal)
            UIView.animate(withDuration: 0.5, animations: {
                self.weekDaysStackView.isHidden = true
                self.calendarViewHeightContraint.constant = 0
                self.view.layoutIfNeeded()
            })
        }
    }
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String)  {
        selectedCellIndexPath = nil
        filterContentForSearchText(searchText: searchText)
    }
    
    func filterContentForSearchText(searchText: String, scope: String = "All") {
        filteredRecords = voiceRecords.filter { record in
            guard let transcript = record.transcript else { return false }
            return transcript.lowercased().contains(searchText.lowercased())
        }
        tableView.reloadData()
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        selectedCellIndexPath = nil
        tableView.reloadData()
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        selectedCellIndexPath = nil
        tableView.reloadData()
    }
}

// MARK: AVAudioPlayerDelegate
extension VoiceTableViewController: AVAudioPlayerDelegate {
    
    func initAudioPlayer() {
        guard
            let selectedCellIndexPath = selectedCellIndexPath,
            let cell = tableView.cellForRow(at: selectedCellIndexPath) as? VoiceTableCellView,
            let voiceRecord = cell.voiceRecord
            else {return}
        
        session = AVAudioSession.sharedInstance()
        try! session!.setCategory(AVAudioSessionCategoryPlayback)
        try! session!.setActive(true)
        
        do {
            try session!.overrideOutputAudioPort(AVAudioSessionPortOverride.speaker)
        } catch {
        }
        
        if let fileURL = voiceRecord.audio.absoluteURL {
            let audioFileName = fileURL.lastPathComponent
            let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            
            let soundFileURL = documentDirectory.appendingPathComponent(audioFileName)
            
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: soundFileURL.path) {
                print("File Avaliable")
                do {
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
        guard
            let selectedCellIndexPath = selectedCellIndexPath,
            let cell = tableView.cellForRow(at: selectedCellIndexPath) as? VoiceTableCellView,
            let player = audioPlayer
            else {return}
        
        player.stop()
        cell.playButton.setImage(#imageLiteral(resourceName: "play") , for: UIControlState.normal)
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        stopAudioPlayer()
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        //stopTimer()
    }
    
    func rewindCurrentFile(timeInterval: TimeInterval) {
        if let audioPlayer = audioPlayer {
            let wasPlaying = audioPlayer.isPlaying
            
            if wasPlaying {
                audioPlayer.stop()
            }
            let newPlayPosition = audioPlayer.currentTime + timeInterval
            if timeInterval >= 0 {
                audioPlayer.currentTime = newPlayPosition >= audioPlayer.duration ? audioPlayer.duration : newPlayPosition
            } else {
                audioPlayer.currentTime = newPlayPosition > 0 ? audioPlayer.currentTime : 0
            }
            
            if wasPlaying {
                audioPlayer.play()
            }
        }
    }
}

extension VoiceTableViewController: ScrollViewRenewable {
    func renew() {
        spinner.startAnimating()
        getVoiceRecordsFromCoreData() { [unowned self] (success: Bool) -> Void in
            if success {
                OperationQueue.main.addOperation() {
                    self.spinner.stopAnimating()
                    self.calendarView.reloadData()
                    self.calendarView.selectDates([Date()], triggerSelectionDelegate: true)
                    self.getTagsFromRecords()
                    self.tableView.reloadData()
                }
            }
        }
        
        formatter.dateFormat = "MMM dd, yyyy"
        calendar.timeZone = TimeZone(abbreviation: "GMT")!
        calendarView.delegate = self
        calendarView.dataSource = self
        calendarView.registerCellViewXib(file: "CalendarCellView")
        calendarView.direction = .horizontal
        calendarView.cellInset = CGPoint(x: 1, y: 1)
        calendarView.allowsMultipleSelection = false
        calendarView.scrollEnabled = true
        calendarView.scrollingMode = .stopAtEachCalendarFrameWidth
        calendarView.itemSize = nil
        calendarView.reloadData()
        
        // After reloading. Scroll to your selected date, and setup your calendar
        
        delayRunOnMainThread(delay: 0.1) {
            self.setupViewsOfCalendar(startDate: Date().firstDayOfMonth(), endDate: Date().lastDayOfMonth())
            self.calendarView.scrollToDate(Date() as Date, triggerScrollToDateDelegate: false, animateScroll: false)
        }
    }
    
    func collapseCalendarWithoutAnimation() {
        collapseCalendarButton.setImage(UIImage(named:"icon_plus"), for: UIControlState.normal)
        self.weekDaysStackView.isHidden = true
        self.calendarViewHeightContraint.constant = 0
        self.view.layoutIfNeeded()
    }
}
