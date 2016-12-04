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

class VoiceTableViewController: UIViewController {

    var voiceRecords:[Voice] = []
    var originRecords:[Voice] = []
    var filteredRecords: [Voice] = []
    var fetchResultController:NSFetchedResultsController<NSFetchRequestResult>!
    var audioFileURL: URL?
    var selectedDate: Date?
    var selectedMonth : Int?
    var selectedYear : Int?
    var taptoHidekeyBoard : UITapGestureRecognizer?
    var scrollView: UIScrollView?
    var searchArray : NSMutableArray!
    

    var searchActive : Bool = false

    @IBOutlet weak var buttonsView: UIView!
  

    let formatter = DateFormatter()
    
    var calendar  = Calendar(identifier: Calendar.Identifier.gregorian)
    var tags = [String]()
    var selectedCellIndexPath:IndexPath?
    
    @IBOutlet weak var searchBarView: UIView!
    let searchController = UISearchController(searchResultsController: nil)
    @IBOutlet weak var monthButton: UIButton!
    @IBOutlet weak var collapseCalendarButton: UIButton!
    @IBOutlet weak var calendarView: JTAppleCalendarView!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var spinner: UIActivityIndicatorView!
    @IBOutlet weak var calendarViewHeightContraint: NSLayoutConstraint!
    @IBOutlet weak var weekDaysStackView: UIStackView!

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.setNeedsLayout()
        self.addGradientFooter()
        self.view.bringSubview(toFront: buttonsView)
        
        view.backgroundColor = UIColor.recordBlack
        searchController.delegate = self
        searchController.searchBar.delegate = self
        searchController.searchResultsUpdater = self
        searchController.searchBar.showsCancelButton = false
        searchController.dimsBackgroundDuringPresentation = false
        definesPresentationContext = true
        
        tableView.delegate = self
        tableView.dataSource = self
        
        view.backgroundColor = UIColor.recordBlack
        searchController.searchBar.frame.size = searchBarView.frame.size
        searchBarView.addSubview(searchController.searchBar)
        searchController.searchBar.searchBarStyle = .minimal
        //searchController.searchBar.isHidden = true
        //self.searchController.hidesNavigationBarDuringPresentation = false
        self.definesPresentationContext = false
        
        let textFieldInsideSearchBar = searchController.searchBar.value(forKey: "searchField") as? UITextField
        textFieldInsideSearchBar?.textColor = UIColor.white
        taptoHidekeyBoard = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        taptoHidekeyBoard?.numberOfTapsRequired = 1
        
        //Magic
//        scrollView?.addConstraint(NSLayoutConstraint(item: self.view, attribute: .right, relatedBy: .equal, toItem: scrollView, attribute: .right, multiplier: 1.0, constant: 0))
        //
        
       // self.automaticallyAdjustsScrollViewInsets = false
        
    }
    
    
    func handleTap(sender: UITapGestureRecognizer? = nil) {
        searchController.searchBar.resignFirstResponder()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        self.tableView.rowHeight = UITableViewAutomaticDimension
        
        spinner.hidesWhenStopped = true
        spinner.center = view.center
        view.addSubview(spinner)
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

            self.calendarView.scrollToDate(Date() as Date, triggerScrollToDateDelegate: false, animateScroll: false)
            self.setupViewsOfCalendar(startDate: Date().firstDayOfMonth(), endDate: Date().lastDayOfMonth())
        }
        
        tableView.backgroundColor = UIColor.clear
        
    }

    @IBAction func onClickMonthButton(sender: AnyObject) {
        
        let monthName = DateFormatter().monthSymbols[(selectedMonth!-1) % 12]
        monthButton.setTitle(monthName, for: UIControlState.normal)
        
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
            originRecords = voiceRecords
            self.tableView.reloadData()
        } catch {
            let fetchError = error as NSError
            print("\(fetchError), \(fetchError.userInfo)")
        }
        
    }

    @IBAction func onBtnCollapseCallender() {
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
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    func setupViewsOfCalendar(startDate: Date, endDate: Date) {
        let month = Calendar.current.component(Calendar.Component.month, from: endDate)
//        let monthName = NSDateFormatter().monthSymbols[(month-1) % 12] // 0 indexed array
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
        monthButton.setTitle(selected, for: UIControlState.normal)
        calendarView.selectDates([keptDate])
//        yearButton.setTitle(String(year), forState: UIControlState.Normal)
        
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
                searchArray = NSMutableArray.init(array: voiceRecords)
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
//            if let recordTags = voiceRecord.objectForKey("tags") as? [String] {
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
        
        switch type {
        case .insert:
            if let _newIndexPath = newIndexPath {
                tableView.insertRows(at: [_newIndexPath], with: .fade)
            }
        case .delete:
            if let _indexPath = indexPath {
                tableView.deleteRows(at: [_indexPath], with: .fade)
                self.voiceRecords.remove(at: _indexPath.row)
                calendarView.reloadData()
            }
        case .update:
            if let _indexPath = indexPath {
                tableView.reloadRows(at: [_indexPath], with: .fade)
            }
            
        default:
            tableView.reloadData()
        }
        
        voiceRecords = controller.fetchedObjects as! [Voice]
        originRecords = voiceRecords
        self.getTagsFromRecords()
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
            //            let count = try self.fetchResultController.managedObjectContext.countForFetchRequest(fetchRequest)
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
        monthButton.setTitle(selected, for: UIControlState.normal)
        selectedDate = endOfDay
        
        let predicate = NSPredicate(format: "(date >= %@) AND (date <=%@)", argumentArray: [startOfDay, endOfDay!])
        
        self.fetchResultController.fetchRequest.predicate = predicate
        do {
            try self.fetchResultController.performFetch()
            voiceRecords = fetchResultController.fetchedObjects as! [Voice]
            originRecords = voiceRecords
            self.tableView.reloadData()
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
        
        if searchController.isActive && searchController.searchBar.text != "" {
            return filteredRecords.count
        }
        return voiceRecords.count
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        let cellIdentifier = "VoiceTableCell"
        let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as! VoiceTableCellView
        
        // Configure the cell...
        let voiceRecord: Voice
        if searchController.isActive && searchController.searchBar.text != "" {
            voiceRecord = filteredRecords[indexPath.row]
        } else {
            voiceRecord = voiceRecords[indexPath.row]
        }
        
        cell.voiceRecord = voiceRecord
        
        cell.backgroundColor = UIColor.clear
        
        let backgroundView = UIView()
        backgroundView.backgroundColor = UIColor.clear
        cell.selectedBackgroundView = backgroundView
        
//        cell.tagView.reloadData()
        return cell
    }
}

// MARK: UITableViewDelegate
extension VoiceTableViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if selectedCellIndexPath == indexPath {
            return 222
        }
        return 70
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        let cellIdentifier = "VoiceTableCell"
        let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as! VoiceTableCellView
        
        if selectedCellIndexPath == indexPath {
            selectedCellIndexPath = nil
            cell.stopAudioPlayer()
            
        } else {
            selectedCellIndexPath = indexPath
            cell.initAudioPlayer()
        }
        
        self.tableView.reloadData()
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
        searchBar.resignFirstResponder()
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
    
   func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder();
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder();
    }
}

extension VoiceTableViewController: UISearchControllerDelegate {
    
    func willPresentSearchController(_ searchController: UISearchController) {
        
        searchController.searchBar.setShowsCancelButton(false, animated: false)
//        searchController.searchBar.becomeFirstResponder()
//        UIView.animate(withDuration: 0.1) { () -> Void in
//            self.view.alpha = 1.0
//            searchController.searchBar.alpha = 1.0
//        }
        
       // searchController.searchBar.setShowsCancelButton(false, animated: false)
    }
}

// MARK: UISearchResultsUpdating
extension VoiceTableViewController: UISearchResultsUpdating {
    
    func updateSearchResults(for searchController: UISearchController) {
        filterContentForSearchText(searchText: searchController.searchBar.text!)
    }
    
    func filterContentForSearchText(searchText: String, scope: String = "All") {
        filteredRecords = voiceRecords.filter { record in
            guard let transcript = record.transcript else { return false }
            return transcript.lowercased().contains(searchText.lowercased())
        }
        tableView.reloadData()
    }
}
