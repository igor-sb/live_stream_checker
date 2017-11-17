//
//  StreamSelectorController.swift
//  Live stream checker
//
//  Created by Igor Segota on 10/19/16.
//  Copyright © 2016 Igor Segota. All rights reserved.
//

import Cocoa

class StreamSelectorController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate {

    @IBOutlet weak var stream_selector_launch: NSButton!
    @IBOutlet weak var stream_selector_cancel: NSButton!
    @IBOutlet weak var stream_selector_list: NSTableView!
    
    @IBAction func launch_selected_stream (_ sender: AnyObject) {
        // Extract the URL of selected streamer from the dictionary and launch app
        let url = streamers_dict[came_online[stream_selector_list.selectedRow]]!.1
        open_stream(url)
        // Close this window
        self.close()
    }
    
    @IBAction func check_stream_selector_launch (_ sender: AnyObject) {
        // When user clicks around the list, check if anything is selected. If it's not, then the button 'Launch' needs to be disabled.
        stream_selector_launch.isEnabled = stream_selector_list.numberOfSelectedRows > 0 ? true : false;
        
    }
    
    @IBAction func close_window (_ sender: AnyObject) {
        self.close()
    }
     
    func numberOfRows(in tableView: NSTableView) -> Int {
        return came_online.count 
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let item = came_online[row]
        if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "streamer_name_id"), owner: nil) as?
            NSTableCellView {
                cell.textField?.stringValue = item
                return cell
        }
        return nil
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
        // Set a delegate and data source for the streamer list
        stream_selector_list.delegate = self
        stream_selector_list.dataSource = self

        // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
    }
    
}
