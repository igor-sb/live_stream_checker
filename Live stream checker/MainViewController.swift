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
    @objc dynamic var is_running = false
    var pipe: Pipe!
    var bash_task: Process!
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
    
    @IBAction func add_streamer_to_list(_ sender: AnyObject) {
        // When + button is pressed, add whatever is in the text field into the list
        // unless we just have an empty text.
        let streamer = text_add_streamer.stringValue
        saved_streamer_list.append(streamer)
        reload_streamer_list()
        
        // save user defaults automatically
        defaults.set(saved_streamer_list, forKey: "saved_streamer_list")
        text_add_streamer.stringValue = ""
    }
    
    @IBAction func remove_streamer_from_list(_ sender: AnyObject) {
        // When - button is pressed remove the selected streamer from the list
        
        // Extract row numbers of selected rows
        let selected_row_ids = streamer_list.selectedRowIndexes
        var selected_rows = [Int]()
        var index = selected_row_ids.first
        while index != nil {
            selected_rows.append(index! as Int)
            index = selected_row_ids.integerGreaterThan(index!)
        }
        
        // Now use these numbers to remove the data from saved_streamers_list
        var new_streamer_list = [String]()
        for (i, val) in saved_streamer_list.enumerated() {
            if !selected_rows.contains(i) {
                new_streamer_list.append(val)
            }
        }
        saved_streamer_list = new_streamer_list
        reload_streamer_list()
        
        // save user defaults
        defaults.set(saved_streamer_list, forKey: "saved_streamer_list")
    }
    
    func reload_streamer_list() {
        // streamer_list.appearance = NSAppearance.init(named: NSAppearanceNameAqua)
        streamer_list.reloadData()
    }
    
    func reload_text_check_interval() {
        // text_check_interval.stringValue = String(check_interval)
    }
    
    @IBAction func oauth_text_save (_ sender: AnyObject) {
        // Load the Oauth key for livestreamer from user defaults
        defaults.set(oauth_text.stringValue, forKey: "livestreamer_oauth")        
    }
    
    @IBAction func import_streamer_list(_ sender: AnyObject) {
        // Extract user whose followed channels we are extracting
        let user = text_import_streamers.stringValue
        is_running = true
        self.button_import_streamers.isEnabled = false
        
        self.bash_task = Process()
        self.pipe = Pipe()
        self.bash_task.launchPath = bash_task_path
        self.bash_task.arguments = bash_task_pars
        self.bash_task.arguments?.append(contentsOf: ["-X", "GET", "https://api.twitch.tv/kraken/users/"+user+"/follows/channels"])
        self.bash_task.terminationHandler = {
            task in
            DispatchQueue.main.async(execute: {
                self.button_import_streamers.isEnabled = true
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
            let json = try JSONSerialization.jsonObject(with: output, options: []) as! [String: AnyObject]
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
        defaults.set(saved_streamer_list, forKey: "saved_streamer_list")

        // Send stdout to pipe and launch task
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        
        // Set a delegate and data source for the streamer list
        streamer_list.delegate = self
        streamer_list.dataSource = self
        
        // Load check_interval value into the text field
        reload_text_check_interval()
        
        // Load all the choices in popup_button
        popup_button_app_open.removeAllItems()
        popup_button_app_open.addItems(withTitles: app_list)
        popup_button_app_open.selectItem(withTitle: (app_open != "") ? app_open : text_default_web_browser)
        
        // Load livestreamer oauth
        oauth_text.stringValue = livestreamer_oauth
        
        // if default app is livestreamer, Load Livestreamer OAuth key, unhide elements
        toggle_oauth_fields()
        
        // Toggle play sound check box if play sound is on
        check_sound.state = play_sound ? .on : .off
    }
    
    @IBAction func toggle_play_sound (_ sender: AnyObject) {
        play_sound = check_sound.state == .on ? true : false
        defaults.set(play_sound, forKey: "play_sound")
    }
    
    func toggle_oauth_fields () {
        if popup_button_app_open.titleOfSelectedItem == text_livestreamer {
            oauth_label.isHidden = false
            oauth_text.isHidden = false
        } else {
            oauth_label.isHidden = true
            oauth_text.isHidden = true
        }
    }
    
    @IBAction func app_open_set_default (_ sender: AnyObject) {
        // Set a new default app for opening streams whenver selection changes
        app_open = popup_button_app_open.titleOfSelectedItem ?? ""
        // print("Setting defualt app open to: "+app_open)
        defaults.set(app_open, forKey: "app_open")
        toggle_oauth_fields()
    }

    @IBAction func quit_application (_ sender: AnyObject) {
        // Quit application
        NSApplication.shared.terminate(self)
    }
    
}

// Need to extend MainViewController class for the table to work
extension MainViewController : NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return saved_streamer_list.count 
    }
}

extension MainViewController : NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            let item = saved_streamer_list[row]
            if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "streamer_name_id"), owner: nil) as?
                NSTableCellView {
                    cell.textField?.stringValue = item
                    // There's a bug with table view and NSPopover that screws the background color in tableview. This fixes that.
                    cell.appearance = NSAppearance.init(named: NSAppearance.Name.aqua)
                    return cell
        }
        return nil
    }
}

class ns_text_field: NSTextField {
    override func textDidChange(_ notification: Notification) {
        defaults.set(self.stringValue, forKey: "livestreamer_oauth")
        super.textDidChange(notification)
    }
}

class ns_popup_button: NSPopUpButton {
    // override func s
}
