//
//  CurrentAppViewController.swift
// 
//  Fluor
//
//  MIT License
//
//  Copyright (c) 2020 Pierre Tacchi
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//


import Cocoa

class CurrentAppViewController: NSViewController, BehaviorDidChangeObserver, ActiveApplicationDidChangeObserver {

    @IBOutlet weak var appIconView: NSImageView!
    @IBOutlet weak var appNameLabel: NSTextField!
    @IBOutlet weak var behaviorSegment: NSSegmentedControl!
    @IBOutlet weak var imageConstraint: NSLayoutConstraint!
    
    internal var currentSwitchMethod = SwitchMethod.window
    
    private var currentAppID: String = ""
    private var currentAppURL: URL?
    
    deinit {
        self.stopObservingBehaviorDidChange()
        self.stopObservingActiveApplicationDidChange()
    }
    
    override func viewDidLoad() {
        self.startObservingBehaviorDidChange()
        self.startObservingActiveApplicationDidChange()
        
        if let currentApp = NSWorkspace.shared.frontmostApplication {
            self.setCurrent(app: currentApp)
        }
    }
    
    func shrinkView() {
        self.currentSwitchMethod = .key
        var newFrame = self.view.frame
        newFrame.size.height = 32
        self.imageConstraint.constant = 24
        self.behaviorSegment.isHidden = true
        self.view.setFrameSize(newFrame.size)
    }
    
    func expandView() {
        self.currentSwitchMethod = .window
        var newFrame = self.view.frame
        newFrame.size.height = 72
        self.imageConstraint.constant = 64
        self.behaviorSegment.isHidden = false
        self.view.setFrameSize(newFrame.size)
    }
    
    @IBAction func behaviorChanged(_ sender: NSSegmentedControl) {
        guard let behavior = AppBehavior(rawValue: sender.selectedSegment), let url = self.currentAppURL else { return }
        AppManager.default.propagate(behavior: behavior, forApp: self.currentAppID, at: url, from: .mainMenu)
    }
    
    private func setCurrent(app: NSRunningApplication) {
        guard let id = app.bundleIdentifier ?? app.executableURL?.lastPathComponent,
            let url = app.bundleURL ?? app.executableURL else { return }
        
        self.currentAppID = id
        self.currentAppURL = url
        let behavior = AppManager.default.behaviorForApp(id: id)
        
        behaviorSegment.setSelected(true, forSegment: behavior.rawValue)
        appIconView.image = app.icon
        if let name = app.localizedName {
            appNameLabel.stringValue = name
        } else {
            appNameLabel.stringValue = NSLocalizedString("An app", comment: "")
        }
    }
    
    func activeApplicationDidChange(notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
        self.setCurrent(app: app)
    }
    
    func behaviorDidChangeForApp(notification: Notification) {
        guard let userInfo = notification.userInfo as? [String: Any], userInfo["source"] as? NotificationSource != .mainMenu else { return }
        guard let id = userInfo["id"] as? String, self.currentAppID == id, let behavior = userInfo["behavior"] as? AppBehavior else { return }
        
        behaviorSegment.setSelected(true, forSegment: behavior.rawValue)
    }
}
