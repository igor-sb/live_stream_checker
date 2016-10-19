//
//  MainViewController.swift
//  Live stream checker
//
//  Created by Igor Segota on 10/16/16.
//  Copyright © 2016 Igor Segota. All rights reserved.
//

import Cocoa

// Main class
class MainViewController: NSViewController {

    // variables for bash tasks
    dynamic var is_running = false
    var pipe: NSPipe!
    var bash_task: NSTask!
    var new_window_controller: StreamSelectorController!
    
    // variables controlling interactions with streamer list
    @IBOutlet var button_add_streamer: NSButton!
    @IBOutlet var button_del_streamer: NSButton!
    @IBOutlet var text_add_streamer: NSTextField!
    @IBOutlet var streamer_list: NSTableView!
    @IBOutlet var button_import_streamers: NSButton!
    @IBOutlet var text_import_streamers: NSTextField!
    @IBOutlet var text_check_interval: NSTextField!
    @IBOutlet var button_check_now: NSButton!
    @IBOutlet var button_quit: NSButton!
        
    @IBAction func add_streamer_to_list(sender: AnyObject) {
        // When + button is pressed, add whatever is in the text field into the list
        // unless we just have an empty text.
        let streamer = text_add_streamer.stringValue
        saved_streamer_list.append(streamer)
        reload_streamer_list()
        
        // save user defaults automatically
        defaults.setObject(saved_streamer_list, forKey: "saved_streamer_list")
        text_add_streamer.stringValue = ""
    }
    
    @IBAction func remove_streamer_from_list(sender: AnyObject) {
        // When - button is pressed remove the selected streamer from the list
        
        // Extract row numbers of selected rows
        let selected_row_ids = streamer_list.selectedRowIndexes
        var selected_rows = [Int]()
        var index = selected_row_ids.firstIndex
        while index != NSNotFound {
            selected_rows.append(index)
            index = selected_row_ids.indexGreaterThanIndex(index)
        }
        
        // Now use these numbers to remove the data from saved_streamers_list
        var new_streamer_list = [String]()
        for (i, val) in saved_streamer_list.enumerate() {
            if !selected_rows.contains(i) {
                new_streamer_list.append(val)
            }
        }
        saved_streamer_list = new_streamer_list
        reload_streamer_list()
        
        // save user defaults
        defaults.setObject(saved_streamer_list, forKey: "saved_streamer_list")
    }
    
    func reload_streamer_list() {
        // streamer_list.appearance = NSAppearance.init(named: NSAppearanceNameAqua)
        streamer_list.reloadData()
    }
    
    func reload_text_check_interval() {
        // text_check_interval.stringValue = String(check_interval)
    }

    @IBAction func import_streamer_list(sender: AnyObject) {
        // Extract user whose followed channels we are extracting
        let user = text_import_streamers.stringValue
        is_running = true
        self.button_import_streamers.enabled = false
        
        self.bash_task = NSTask()
        self.pipe = NSPipe()
        self.bash_task.launchPath = bash_task_path
        self.bash_task.arguments = bash_task_pars
        self.bash_task.arguments?.appendContentsOf(["-X", "GET", "https://api.twitch.tv/kraken/users/"+user+"/follows/channels"])
        self.bash_task.terminationHandler = {
            task in
            dispatch_async(dispatch_get_main_queue(), {
                self.button_import_streamers.enabled = true
                self.is_running = false
            })
        }
        
        self.bash_task.standardOutput = self.pipe
        self.pipe.fileHandleForReading.waitForDataInBackgroundAndNotify()
        
        self.bash_task.launch()
        self.bash_task.waitUntilExit()
        let output = self.pipe.fileHandleForReading.readDataToEndOfFile()

        // Parse Twitch output as JSON
        do {
            let json = try NSJSONSerialization.JSONObjectWithData(output, options: [])
            if let follows = json["follows"] as? [AnyObject] {
                // Iterate over following channels
                for metadata in follows {
                    let channel = metadata["channel"] as! [String: AnyObject]
                    let name = channel["name"] as! String
                    print(name)
                    if !saved_streamer_list.contains(name) {
                        saved_streamer_list.append(name)
                    }
                }
                
            } else {
                // can't retrieve followed channels. probably invalid user?
                // print("Invalid user specified.")
            }
        } catch {
            print("Error parsin JSON output: \(error)")
        }
        // update the text field with new streamer list
        reload_streamer_list()
        text_import_streamers.stringValue = ""
        // Send stdout to pipe and launch task
        //for streamer in streamers {
        
    }
    
    @IBAction func get_online_stremers_now(sender: AnyObject) {
        self.button_check_now.enabled = false
        return_online_streamers()
        if came_online.count > 0 {
            display_notification()
        }
        self.button_check_now.enabled = true
    }
    
    func open_stream_selector() {
        let alert = NSAlert()
        alert.messageText = "Select stream to open:"

    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        
        // Set a delegate and data source for the streamer list
        streamer_list.setDelegate(self)
        streamer_list.setDataSource(self)
        
        // Load check_interval value into the text field
        reload_text_check_interval()
    }

    @IBAction func quit_application (sender: AnyObject) {
        NSApplication.sharedApplication().terminate(self)
    }
    
}

// Need to extend MainViewController class for the table to work
extension MainViewController : NSTableViewDataSource {
    func numberOfRowsInTableView(tableView: NSTableView) -> Int {
        return saved_streamer_list.count ?? 0
    }
}

extension MainViewController : NSTableViewDelegate {
    func tableView(tableView: NSTableView, viewForTableColumn tableColumn: NSTableColumn?, row: Int) -> NSView? {
            let item = saved_streamer_list[row]
            if let cell = tableView.makeViewWithIdentifier("streamer_name_id", owner: nil) as?
                NSTableCellView {
                    cell.textField?.stringValue = item
                    // There's a bug with table view and NSPopover that screws the background color in tableview. This fixes that.
                    cell.appearance = NSAppearance.init(named: NSAppearanceNameAqua)
                    return cell
        }
        return nil
    }
}