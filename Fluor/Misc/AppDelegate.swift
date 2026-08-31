//
//  AppDelegate.swift
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

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    // Retain the nib-created delegate because NSApplication.delegate is non-owning.
    private static var retainedInstance: AppDelegate?

    let statusMenuController: StatusMenuController = .init()
    private var mainMenuTopLevelObjects: [Any] = []
    private var ongoingMenuBarActivity: NSObjectProtocol?

    override func awakeFromNib() {
        super.awakeFromNib()
        AppDelegate.retainedInstance = self
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            let processInfo = ProcessInfo.processInfo
            processInfo.automaticTerminationSupportEnabled = true
            self?.ongoingMenuBarActivity = processInfo.beginActivity(
                options: .automaticTerminationDisabled,
                reason: "Fluor provides ongoing menu bar functionality"
            )
        }

        ValueTransformer.setValueTransformer(RuleValueTransformer(), forName: NSValueTransformerName("RuleValueTransformer"))
        
        UserNotificationHelper.askUserAtLaunch()
        
        self.loadMainMenu()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            statusMenuController.showPreferencesWindow()
        }
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        statusMenuController.performTerminationCleaning()
        if let activity = ongoingMenuBarActivity {
            ProcessInfo.processInfo.endActivity(activity)
            ongoingMenuBarActivity = nil
        }
    }

    private func loadMainMenu() {
        guard self.mainMenuTopLevelObjects.isEmpty else { return }
        let nib = NSNib(nibNamed: "MainMenu", bundle: nil)
        var topLevelObjects: NSArray?
        nib?.instantiate(withOwner: self.statusMenuController, topLevelObjects: &topLevelObjects)
        self.mainMenuTopLevelObjects = topLevelObjects as? [Any] ?? []
    }
    
    func windowWillClose(_ notification: Notification) {
        self.loadMainMenu()
    }
}
