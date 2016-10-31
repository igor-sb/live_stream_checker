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
    @IBOutlet var button_quit: NSButton!
    @IBOutlet var popup_button_app_open: NSPopUpButton!
    @IBOutlet var oauth_label: NSTextField!
    @IBOutlet var oauth_text: ns_text_field!
    @IBOutlet var check_sound: NSButton!
    
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
    
    @IBAction func oauth_text_save (sender: AnyObject) {
        // Load the Oauth key for livestreamer from user defaults
        defaults.setObject(oauth_text.stringValue, forKey: "livestreamer_oauth")        
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
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        
        // Set a delegate and data source for the streamer list
        streamer_list.setDelegate(self)
        streamer_list.setDataSource(self)
        
        // Load check_interval value into the text field
        reload_text_check_interval()
        
        // Load all the choices in popup_buttob
        popup_button_app_open.removeAllItems()
        popup_button_app_open.addItemsWithTitles(app_list)
        popup_button_app_open.selectItemWithTitle((app_open != "") ? app_open : text_default_web_browser)
        
        // Load livestreamer oauth
        oauth_text.stringValue = livestreamer_oauth
        
        // if default app is livestreamer, Load Livestreamer OAuth key, unhide elements
        toggle_oauth_fields()
        
        // Toggle play sound check box if play sound is on
        check_sound.enabled = play_sound ? true : false
    }
    
    @IBAction func toggle_play_sound (sender: AnyObject) {
        play_sound = check_sound.enabled ? true : false
        defaults.setObject(play_sound, forKey: "play_sound")
    }
    
    func toggle_oauth_fields () {
        if popup_button_app_open.titleOfSelectedItem == text_livestreamer {
            oauth_label.hidden = false
            oauth_text.hidden = false
        } else {
            oauth_label.hidden = true
            oauth_text.hidden = true
        }
    }
    
    @IBAction func app_open_set_default (sender: AnyObject) {
        // Set a new default app for opening streams whenver selection changes
        app_open = popup_button_app_open.titleOfSelectedItem ?? ""
        // print("Setting defualt app open to: "+app_open)
        defaults.setObject(app_open, forKey: "app_open")
        toggle_oauth_fields()
    }

    @IBAction func quit_application (sender: AnyObject) {
        // Quit application
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

class ns_text_field: NSTextField {
    override func textDidChange(notification: NSNotification) {
        defaults.setObject(self.stringValue, forKey: "livestreamer_oauth")
        super.textDidChange(notification)
    }
}

class ns_popup_button: NSPopUpButton {
    // override func s
}
