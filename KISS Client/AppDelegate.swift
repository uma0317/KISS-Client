//
//  AppDelegate.swift
//  KISS Client
//
//  Created by yuuma0317 on 2019/11/16.
//  Copyright © 2019 yuuma0317. All rights reserved.
//

import Cocoa
import SwiftUI
import Network

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, NSUserNotificationCenterDelegate {
    var window: NSWindow!
    var send = false
    
    var client = Client();
    var runLoopSource: CFRunLoopSource?
    @IBOutlet var statusMenu: NSMenu?
    var statusBarItem : NSStatusItem?
    
    @IBOutlet weak var menu: NSMenu!

    //メニューバーに表示されるアプリケーションを作成
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        //Status menu設定
        self.statusItem.title = "💋"
        self.statusItem.highlightMode = true
        let statusBarMenu = NSMenu(title: "Cap Status Bar Menu")
        statusBarMenu.addItem(
            withTitle: "Quit Kiss",
            action: #selector(AppDelegate.quit),
            keyEquivalent: "q")
        statusItem.menu = statusBarMenu
        
        //通知設定
        NSUserNotificationCenter.default.delegate = self
        
        //アクセシビリティチェック
        let trusted = kAXTrustedCheckOptionPrompt.takeUnretainedValue()
        let privOptions = [String(trusted):true]
        let accessEnabled = AXIsProcessTrustedWithOptions(privOptions as CFDictionary?)
        
        //アクセスが有効なでなければ終了
        if accessEnabled != true {
            let alert = NSAlert()
            alert.messageText = "アクセシビリティを有効にして下さい"
            alert.informativeText = "初回のみアクセシビリティの設定が必要です。このアプリへのアクセスを有効にして下さい。"
            let response = alert.runModal()
            NSRunningApplication.current.activate(options: NSApplication.ActivationOptions.activateIgnoringOtherApps)

            if (response == NSApplication.ModalResponse.cancel) {
                quit()
            }
        }
        
        print("Access OK")
        self.client = Client();
        client.startConnection(to: "192.168.11.2:33333")

        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) {
            (event)in
            if(self.send) {

            } else {
                switch event.modifierFlags.intersection(.deviceIndependentFlagsMask) {
                    
                    case [.control] where event.characters! == "|":
                        self.send = true
                        self.sendNortification(message: "Start sync")
                        disableKeyboard()
                        print("send: {}", self.send)
                        break
                    default:
                        break
                }
            }
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    
    @objc func quit() {
        NSApplication.shared.terminate(self)
    }
    
    func sendNortification(message: String) {
         let notification = NSUserNotification()
         notification.title = "KISS"
         notification.informativeText = message
         notification.contentImage =  NSImage(named: "blue")
         notification.userInfo = ["title" : "タイトル"]
         notification.deliveryDate = NSDate().addingTimeInterval(2.0) as Date
         NSUserNotificationCenter.default.scheduleNotification(notification)
         NSUserNotificationCenter.default.deliver(notification)
     }
    
    func userNotificationCenter(_ center: NSUserNotificationCenter,
                                         didDeliver notification: NSUserNotification) {
        
    }
    
    func userNotificationCenter(_ center: NSUserNotificationCenter,
                                         didActivate notification: NSUserNotification) {
        
    }
    
    func userNotificationCenter(_ center: NSUserNotificationCenter,
                                         shouldPresent notification: NSUserNotification) -> Bool {
        return true
    }
}

class Client {
    private var connection: NWConnection!
    let networkType = "_networkplayground._udp."
    let networkDomain = "local"
    func startConnection(to name: String) {
        self.connection = NWConnection(host: "192.168.11.2", port: 33333, using: NWParameters.udp)
        connection.stateUpdateHandler = { (state: NWConnection.State) in
            guard state != .ready else { return }
            print("connection is ready")
        }
        
        // コネクション開始
        let connectionQueue = DispatchQueue(label: "com.uma0317.NetworkPlayground.sender")
        connection.start(queue: connectionQueue)
    }

    func send(message: String) {
        let data = message.data(using: .utf8)!
        print(message)
        // 送信完了時の処理
        let completion = NWConnection.SendCompletion.contentProcessed { (error: NWError?) in
            print("送信完了")
        }

        connection.send(content: data, completion: completion)
    }
}

public func enableKeyboard() {
    guard let appDelegate = NSApplication.shared.delegate as? AppDelegate else { return }
    guard let runLoopSource = appDelegate.runLoopSource else { return }
    CFRunLoopSourceInvalidate(runLoopSource)
    CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
    appDelegate.runLoopSource = nil
}

func disableKeyboard() {
        guard let appDelegate = NSApplication.shared.delegate as? AppDelegate else { return }
        guard appDelegate.runLoopSource == nil else { return }
        guard appDelegate.send == true else { return }
//        guard let event = GlobalVar.event else {return}
        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask((1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.flagsChanged.rawValue)),
            callback: handle,
            userInfo: UnsafeMutableRawPointer(Unmanaged.passRetained(appDelegate).toOpaque())
        ) else {
            print("failed to create event tap")
            exit(1)
        }
        print("disable")
    appDelegate.runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
    CFRunLoopAddSource(CFRunLoopGetCurrent(), appDelegate.runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }

public func handle(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    print(type)
    let fromAppDelegate: AppDelegate = NSApplication.shared.delegate as! AppDelegate
    print(fromAppDelegate.send)
    print(event.flags)
    print(event.getIntegerValueField(.keyboardEventKeycode))
    if fromAppDelegate.send {
        let code = event.getIntegerValueField(.keyboardEventKeycode)
        switch event.flags.rawValue {
            // ctrl + ¥ (prefix)
            case 262401 where code == 93:
                fromAppDelegate.send = false

                fromAppDelegate.sendNortification(message: "Stop sync")
                enableKeyboard()
                break
            //ctrl
            case 262401:
                 fromAppDelegate.client.send(message: "ct," + String(code))
                 break
            
            //cmd
            case 1048840, 1048848:
                fromAppDelegate.client.send(message: "c," + String(code))
                break

            // cmd + shift
            case 1179914, 1179916, 1179922, 1179924, 393477, 393475:
                fromAppDelegate.client.send(message: "cs," + String(code))
                break
            //shift
            case 131330, 131332:
                fromAppDelegate.client.send(message: "s," + String(code))
                break
            
            //cmd + ctrl
            case 1310985, 1310993:
                break
            
            //cmd + arrow
            case 11534600, 11534608, 10748161:
                fromAppDelegate.client.send(message: "c," + String(code))
                break
            //shift + arrow
            case 10617090, 10617092:
                fromAppDelegate.client.send(message: "s," + String(code))
                break
            
            //alt
            case 524576:
                fromAppDelegate.client.send(message: "a," + String(code))
                break
            //fn
            case 8388864:
                fromAppDelegate.client.send(message: "f," + String(code))
                break
            default:
                fromAppDelegate.client.send(message: String(code))
                break

        }
    } else {

    }

    print("disable handle")
    if [.keyDown, .flagsChanged].contains(type) {
        print(event.getIntegerValueField(.keyboardEventKeycode));
        let keyCode: Int64 = 9999 // this keycode does not exist.
        
        event.setIntegerValueField(.keyboardEventKeycode, value: keyCode)
    }
    return Unmanaged.passRetained(event)
}
