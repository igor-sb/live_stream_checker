//
//  AppDelegate.swift
//  Live stream checker
//
//  Created by Igor Segota on 10/16/16.
//  Copyright © 2016 Igor Segota. All rights reserved.
//
// To do: When the computer wakes up from sleep, this crashes
//        when clicking on streamer notfication. Check when notification
//        was created or something and prevent clicking.

import Cocoa


// Load streamer list from user defaults (if they exist)
var defaults = UserDefaults.standard
var saved_streamer_list: [String] = defaults.object(forKey: "saved_streamer_list") as? [String] ?? []
// Streamers dict. Key: streamer_name, Value: display_name, url, true/false (online status)
var streamers_dict = [String: (String, String, Bool)]()

// List of streamers who were offline but came online
var came_online = [String]()

// Interval in minutes to recheck status of all streamers
var check_interval: Int = defaults.object(forKey: "check_interval") as? Int ?? 1

// Stream application. What application to run when the stream is open?
let text_default_web_browser = "default web browser"
let text_livestreamer = "livestreamer"
var app_open: String = defaults.object(forKey: "app_open") as? String ?? text_default_web_browser
var app_list: [String] = [text_default_web_browser, text_livestreamer]
var livestreamer_oauth: String = defaults.object(forKey: "livestreamer_oauth") as? String ?? ""
var play_sound: Bool = defaults.object(forKey: "play_sound") as? Bool ?? true

// Bash script common arguments, Twitch Cliend-ID for this app and version
let bash_task_path = "/usr/bin/curl"
let bash_task_pars = ["-H", "Client-ID: jk0r7xgh72b2g2e7d0vidk4uvd85xu",
    "-H", "Accept: application/vnd.twitchtv.v3+json"]

// Main application delegate
@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, NSUserNotificationCenterDelegate {

    // Initialize status bar application mode and popover window
    let statusItem = NSStatusBar.system.statusItem(withLength: -2)
    let popover = NSPopover()
    var stream_select: StreamSelectorController!

    @IBOutlet weak var window: NSWindow!
    
    // variables for bash tasks
    @objc dynamic var is_running = false
    var pipe: Pipe!
    var bash_task: Process!    

    // This is executed when application starts
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        
        // Select the image for status bar and call toggle_popover
        if let button = statusItem.button {
            button.image = NSImage(named: NSImage.Name(rawValue: "StatusBarButtonImage"))
            button.action = #selector(AppDelegate.toggle_popover(_:))
        }
        
        // Initialize main popover window
        popover.contentViewController = MainViewController(nibName: NSNib.Name(rawValue: "MainViewController"), bundle: nil)
        // This hides the popover when we click somewhere outside of it
        popover.behavior = NSPopover.Behavior.transient
        
        // Delegate for Notification center
        NSUserNotificationCenter.default.delegate = self

        // Immediately check for online streamers on start
        check_online_and_notify()
        
        // Run a timer
        Timer.scheduledTimer(timeInterval: 60.0*Double(check_interval), target: self, selector: #selector(AppDelegate.check_online_and_notify), userInfo: nil, repeats: true)

    }
    
    @objc func check_online_and_notify() {
        // Check for online streamers and send notification if anyone new came online
        return_online_streamers()
        if came_online.count > 0 {
            display_notification()
        }
        //print("Online check performed.")
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    
    // These functions control the popover (window attached to status bar) display on and off
    func show_popover(_ sender: AnyObject?) {
        if let button = statusItem.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
        }
    }
    
    func close_popover(_ sender: AnyObject?) {
        popover.performClose(sender)
    }
    @objc func toggle_popover(_ sender: AnyObject?) {
        if popover.isShown {
            close_popover(sender)
        } else {
            show_popover(sender)
        }
    }

    
    func userNotificationCenter(_ center: NSUserNotificationCenter, shouldPresent notification: NSUserNotification) -> Bool {
        // return true to always display the User Notification
        return true
    }
    
    func userNotificationCenter(_ center: NSUserNotificationCenter, didActivate notification: NSUserNotification) {
        // Get the path from the userInfo dictionary of the User Notification
        // let path = notification.userInfo!["path"] as! String
        
        // Check JSON output here and if it's not good, don't open stream.
        // Looks like this happens when computer wakes from sleep.
        // This also crashes if we click notification from the notification bar.
        //
        //Error parsin JSON output: Error Domain=NSCocoaErrorDomain Code=3840 "No value." UserInfo={NSDebugDescription=No value.}
        //Error parsin JSON output: Error Domain=NSCocoaErrorDomain Code=3840 "No value." UserInfo={NSDebugDescription=No value.}
        //fatal error: Index out of range
        //2017-01-02 00:56:55.131282 Live stream checker[50815:1801692] fatal error: Index out of range
        
        // Open the file at the path
        if came_online.count > 1 {
            // select stream to open
            stream_select = StreamSelectorController(windowNibName: NSNib.Name(rawValue: "StreamSelectorController"))
            stream_select.showWindow(nil)
        } else {
            // just one streamer is online. open that one
            open_stream(streamers_dict[came_online[0]]!.1)
        }
    }

}


func open_stream(_ url: String) {
    // Opens the stream from 'url'
    switch app_open {
    case text_default_web_browser:
        NSWorkspace.shared.open(URL(string: url)!)
    case text_livestreamer:
        // launch livestreamer using NSTask():
        let ls_task: Process! = Process()
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

    // reset came_online
    came_online = [String]()
    // keep a list of streamers that are online
    // var streamers_online = [String]()

    let bash_task: Process! = Process()
    let pipe: Pipe! = Pipe()
    // var is_running: Bool = true
    
    bash_task.launchPath = bash_task_path
    bash_task.arguments = bash_task_pars
    
    bash_task.terminationHandler = {
        task in
        DispatchQueue.main.async(execute: {
            // is_running = false
        })
    }
    
    // Send stdout to pipe and launch task
    // for streamer in streamers {
    bash_task.arguments?.append("https://api.twitch.tv/kraken/streams?channel=" + saved_streamer_list.joined(separator: ","))
    bash_task.standardOutput = pipe
    bash_task.standardError = nil
    bash_task.launch()
    bash_task.waitUntilExit()
    
    let output = pipe.fileHandleForReading.readDataToEndOfFile()
    // let output_string = String(data: output, encoding: NSUTF8StringEncoding) ?? ""
    
    // Parse Twitch JSON output
    do {
        let json = try JSONSerialization.jsonObject(with: output, options: []) as! [String: AnyObject]
        if (json["_total"] != nil) {
            let online_total = json["_total"] as! Int
            // If there is at least one person online collect the names
            if online_total > 0 {
                let json_array = json["streams"] as! [AnyObject]
                for i in 0..<online_total {
                    let streamer_metadata = json_array[i] as! [String: AnyObject]
                    let channel_metadata = streamer_metadata["channel"] as! [String: AnyObject]
                    let streamer = channel_metadata["name"] as! String
                    let streamer_display = channel_metadata["display_name"] as! String
                    let streamer_url = channel_metadata["url"] as! String
                    if let streamer_data = streamers_dict[streamer] {
                        if streamer_data.2 == false {
                            came_online.append(streamer)
                        } else {
                            // this streamer is online and was online also on last check
                            //if let came_online_id = came_online.index(of: streamer) {
                            //    came_online.remove(at: came_online_id)
                            //}
                        }
                    } else {
                        // This streamer wasn't even in the dict. This can happen only during startup or if we deleted a streamer.
                        //print("Is this startup?")
                        came_online.append(streamer)
                    }
                    streamers_dict[streamer] = (streamer_display, streamer_url, true)
                    // streamers_online.append(streamer)
                    // print("Stremer \(streamer_display) is now set to true.")
                }
            } else {
                // online_total == 0
                // print("Noone is online.")
            }
            // Now set every streamer not in the json report as 'offline'
            for (streamer, _) in streamers_dict {
                if came_online.contains(streamer) {
                    streamers_dict[streamer]!.2 = true
                }
            }
        } // end if json['total'] != nil (if this isn't true twitch returned an error
        else {
            // catch Twitch error message here
            let output_text = String(data: output, encoding: String.Encoding.utf8)
            print("Twitch returned error.")
            print("--- Output pipe ---")
            print(output_text!)
        }
    } catch {
        print("Error parsin JSON output: \(error)")
    }
    // print("Streamer dict: "+String(describing: streamers_dict))
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
    notification.informativeText = online_streamers.joined(separator: ", ")
    
    // put the path to the created text file in the userInfo dictionary of the notification
    // notification.userInfo = ["path" : fileName]
    
    // use the default sound for a notification
    if play_sound {
        notification.soundName = NSUserNotificationDefaultSoundName
    }
    
    // if the user chooses to display the notification as an alert, give it an action button called "View"
    notification.hasActionButton = true
    notification.actionButtonTitle = "View"
    
    // Deliver the notification through the User Notification Center
    NSUserNotificationCenter.default.deliver(notification)
}
