//
//  AppDelegate.swift
//  Live stream checker
//
//  Created by Igor Segota on 10/16/16.
//  Copyright © 2016 Igor Segota. All rights reserved.
//

import Cocoa


// Load streamer list from user defaults (if they exist)
var defaults = NSUserDefaults.standardUserDefaults()
var saved_streamer_list: [String] = defaults.objectForKey("saved_streamer_list") as? [String] ?? []
// Streamers dict. Key: streamer_name, Value: display_name, url, true/false (online status)
var streamers_dict = [String: (String, String, Bool)]()

// List of streamers who were offline but came online
var came_online = [String]()

// Interval in minutes to recheck status of all streamers
var check_interval: Int = defaults.objectForKey("check_interval") as? Int ?? 1

// Stream application. What application to run when the stream is open?
let text_default_web_browser = "default web browser"
let text_livestreamer = "livestreamer"
var app_open: String = defaults.objectForKey("app_open") as? String ?? text_default_web_browser
var app_list: [String] = [text_default_web_browser, text_livestreamer]
var livestreamer_oauth: String = defaults.objectForKey("livestreamer_oauth") as? String ?? ""
var play_sound: Bool = defaults.objectForKey("play_sound") as? Bool ?? true

// Bash script common arguments
let bash_task_path = "/usr/bin/curl"
let bash_task_pars = ["-H", "Client-ID: jk0r7xgh72b2g2e7d0vidk4uvd85xu",
    "-H", "Accept: application/vnd.twitchtv.v3+json"]

// Main application delegate
@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, NSUserNotificationCenterDelegate {

    // Initialize status bar application mode and popover window
    let statusItem = NSStatusBar.systemStatusBar().statusItemWithLength(-2)
    let popover = NSPopover()
    var stream_select: StreamSelectorController!

    @IBOutlet weak var window: NSWindow!
    
    // variables for bash tasks
    dynamic var is_running = false
    var pipe: NSPipe!
    var bash_task: NSTask!    

    // This is executed when application starts
    func applicationDidFinishLaunching(aNotification: NSNotification) {
        
        // Select the image for status bar and call toggle_popover
        if let button = statusItem.button {
            button.image = NSImage(named: "StatusBarButtonImage")
            button.action = Selector("toggle_popover:")
        }
        
        // Initialize main popover window
        popover.contentViewController = MainViewController(nibName: "MainViewController", bundle: nil)
        // This hides the popover when we click somewhere outside of it
        popover.behavior = NSPopoverBehavior.Transient
        
        // Delegate for Notification center
        NSUserNotificationCenter.defaultUserNotificationCenter().delegate = self

        // Immediately check for online streamers on start
        check_online_and_notify()
        
        // Run a timer
        NSTimer.scheduledTimerWithTimeInterval(60.0*Double(check_interval), target: self, selector: Selector("check_online_and_notify"), userInfo: nil, repeats: true)

        
    }
    
    func check_online_and_notify() {
        // Check for online streamers and send notification if anyone new came online
        return_online_streamers()
        if came_online.count > 0 {
            display_notification()
        }
        print("Online check performed.")
    }

    func applicationWillTerminate(aNotification: NSNotification) {
        // Insert code here to tear down your application
    }

    
    // These functions control the popover (window attached to status bar) display on and off
    func show_popover(sender: AnyObject?) {
        if let button = statusItem.button {
            popover.showRelativeToRect(button.bounds, ofView: button, preferredEdge: NSRectEdge.MinY)
        }
    }
    
    func close_popover(sender: AnyObject?) {
        popover.performClose(sender)
    }
    func toggle_popover(sender: AnyObject?) {
        if popover.shown {
            close_popover(sender)
        } else {
            show_popover(sender)
        }
    }

    
    func userNotificationCenter(center: NSUserNotificationCenter, shouldPresentNotification notification: NSUserNotification) -> Bool {
        // return true to always display the User Notification
        return true
    }
    
    func userNotificationCenter(center: NSUserNotificationCenter, didActivateNotification notification: NSUserNotification) {
        // Get the path from the userInfo dictionary of the User Notification
        // let path = notification.userInfo!["path"] as! String
        
        // Open the file at the path
        if came_online.count > 1 {
            // select stream to open
            stream_select = StreamSelectorController(windowNibName: "StreamSelectorController")
            stream_select.showWindow(nil)
        } else {
            // just one streamer is online. open that one
            open_stream(streamers_dict[came_online[0]]!.1)
        }
    }

}


func open_stream(url: String) {
    // Opens the stream from 'url'
    switch app_open {
    case text_default_web_browser:
        NSWorkspace.sharedWorkspace().openURL(NSURL(string: url)!)
    case text_livestreamer:
        // launch livestreamer using NSTask():
        let ls_task: NSTask! = NSTask()
        ls_task.launchPath = "/usr/local/bin/livestreamer"
        ls_task.arguments = ["--twitch-oauth-token", livestreamer_oauth, url, "best"]
        ls_task.launch()
        // ls_task.
    default:
        print("We should never have an undefined default open app.")
    }
    
}

// Check streamers from saved_streamer_list for online status and return the online streamers
func return_online_streamers() {

    // keep a list of streamers that are online
    var streamers_online = [String]()

    let bash_task: NSTask! = NSTask()
    let pipe: NSPipe! = NSPipe()
    var is_running: Bool = true
    
    bash_task.launchPath = bash_task_path
    bash_task.arguments = bash_task_pars
    
    bash_task.terminationHandler = {
        task in
        dispatch_async(dispatch_get_main_queue(), {
            is_running = false
        })
    }
    
    // Send stdout to pipe and launch task
    // for streamer in streamers {
    bash_task.arguments?.append("https://api.twitch.tv/kraken/streams?channel=" + saved_streamer_list.joinWithSeparator(","))
    bash_task.standardOutput = pipe
    bash_task.standardError = nil
    bash_task.launch()
    bash_task.waitUntilExit()
    
    let output = pipe.fileHandleForReading.readDataToEndOfFile()
    // let output_string = String(data: output, encoding: NSUTF8StringEncoding) ?? ""
    
    // Parse Twitch JSON output
    do {
        let json = try NSJSONSerialization.JSONObjectWithData(output, options: [])
        let online_total = json["_total"] as! Int
        // If there is at least one person online collect the names
        // print(json["streams"])
        if online_total > 0 {
            let json_array = json["streams"] as! [AnyObject]
            for i in 0..<online_total {
                let streamer_metadata = json_array[i] as! [String: AnyObject]
                let channel_metadata = streamer_metadata["channel"] as! [String: AnyObject]
                let streamer = channel_metadata["name"] as! String
                let streamer_display = channel_metadata["display_name"] as! String
                let streamer_url = channel_metadata["url"] as! String
                // print("Checking \(streamer)...")
                if let streamer_data = streamers_dict[streamer] {
                    // print("Stremer name in dict.")
                    // print(streamer_data)
                    if streamer_data.2 == false {
                        came_online.append(streamer)
                    } else {
                        // this streamer is online and was online also on last check
                        if let came_online_id = came_online.indexOf(streamer) {
                            came_online.removeAtIndex(came_online_id)
                        }
                    }
                } else {
                    // This streamer wasn't even in the dict. This can happen only during startup or if we deleted a streamer.
                    //print("Is this startup?")
                    came_online.append(streamer)
                }
                streamers_dict[streamer] = (streamer_display, streamer_url, true)
                streamers_online.append(streamer)
                //print("Stremer \(streamer_display) is now set to true.")
            }
        } else {
            // online_total == 0
            
        }
        // Now set every streamer not in the json report as 'offline'
        for streamer in streamers_online {
            streamers_dict[streamer] = (streamers_dict[streamer]!.0, streamers_dict[streamer]!.1, false)
        }
    } catch {
        print("Error parsin JSON output: \(error)")
    }
    print("Streamer dict: "+String(streamers_dict))
    // online_streamer_list = online_streamers
    // online_streamer_list_display = online_streamers_display
}

func display_notification() {
    // create a User Notification
    let notification = NSUserNotification.init()
    
    // set the title and the informative text
    notification.title = "Online streams:"
    var online_streamers = [String]()
    for streamer in came_online {
        online_streamers.append(streamers_dict[streamer]!.0)
    }
    notification.informativeText = online_streamers.joinWithSeparator(", ")
    
    // put the path to the created text file in the userInfo dictionary of the notification
    // notification.userInfo = ["path" : fileName]
    
    // use the default sound for a notification
    notification.soundName = play_sound ? NSUserNotificationDefaultSoundName : ""
    
    // if the user chooses to display the notification as an alert, give it an action button called "View"
    notification.hasActionButton = true
    notification.actionButtonTitle = "View"
    
    // Deliver the notification through the User Notification Center
    NSUserNotificationCenter.defaultUserNotificationCenter().deliverNotification(notification)
}