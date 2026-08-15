//
//  StatusMenuController.swift
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

class StatusMenuController: NSObject, NSMenuDelegate, NSWindowDelegate, MenuControlObserver {
    @IBOutlet weak var statusMenu: NSMenu!
    @IBOutlet var menuItemsController: MenuItemsController!
    @IBOutlet var behaviorController: BehaviorController!

    private var rulesController: RulesEditorWindowController?
    private var aboutController: AboutWindowController?
    private var preferencesController: PreferencesWindowController?
    private var runningAppsController: RunningAppWindowController?
    
    var statusItem: NSStatusItem!

    override func awakeFromNib() {
        setupStatusMenu()
        self.menuItemsController.setupController()
        self.behaviorController.setupController()
        startObservingUsesLightIcon()
        startObservingMenuBarVisibility()
        startObservingMenuControlNotification()
    }
    
    deinit {
        stopObservingUsesLightIcon()
        stopObservingMenuBarVisibility()
        stopObservingSwitchMenuControlNotification()
    }
    
    func windowWillClose(_ notification: Notification) {
        guard let object = notification.object as? NSWindow else { return }
        NotificationCenter.default.removeObserver(self, name: NSWindow.willCloseNotification, object: object)
        if object.isEqual(rulesController?.window) {
            rulesController = nil
        } else if object.isEqual(aboutController?.window) {
            aboutController = nil
        } else if object.isEqual(preferencesController?.window) {
            preferencesController = nil
        } else if object.isEqual(runningAppsController?.window) {
            runningAppsController = nil
        }
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        switch keyPath {
        case SettingsKey.useLightIcon?:
            adaptStatusMenuIcon()
        case SettingsKey.hideMenuBarItem?:
            applyMenuBarVisibility()
        default:
            return
        }
    }
    
    private func setupStatusMenu() {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.statusItem.autosaveName = "FluorStatusItem"
        self.statusItem.isVisible = !AppManager.default.hideMenuBarItem
        self.statusItem.menu = statusMenu
        adaptStatusMenuIcon()
    }

    private func applyMenuBarVisibility() {
        statusItem.isVisible = !AppManager.default.hideMenuBarItem
    }
    
    func setStatusImage(_ image: NSImage) {
        statusItem.button?.title = ""
        statusItem.button?.image = image
        statusItem.button?.toolTip = "Fluor"
        statusItem.button?.setAccessibilityLabel("Fluor")
    }

    private func adaptStatusMenuIcon() {
        let disabledApp = AppManager.default.isDisabled
        let usesLightIcon = AppManager.default.useLightIcon
        let image: NSImage
        switch (disabledApp, usesLightIcon) {
        case (false, let usesLightIcon): image = MediaModeIcon.image(usesBackground: !usesLightIcon)
        case (true, false): image = #imageLiteral(resourceName: "IconDisabled")
        case (true, true): image = #imageLiteral(resourceName: "LighIconDisabled")
        }
        setStatusImage(image)
    }
    
    private func startObservingUsesLightIcon() {
        UserDefaults.standard.addObserver(self, forKeyPath: SettingsKey.useLightIcon, options: [], context: nil)
    }
    
    private func stopObservingUsesLightIcon() {
        UserDefaults.standard.removeObserver(self, forKeyPath: SettingsKey.useLightIcon, context: nil)
    }

    private func startObservingMenuBarVisibility() {
        UserDefaults.standard.addObserver(self, forKeyPath: SettingsKey.hideMenuBarItem, options: [], context: nil)
    }

    private func stopObservingMenuBarVisibility() {
        UserDefaults.standard.removeObserver(self, forKeyPath: SettingsKey.hideMenuBarItem, context: nil)
    }
    
    
    func menuWillOpen(_ menu: NSMenu) {
        self.behaviorController.adaptToAccessibilityTrust()
    }
    
    
    func menuNeedsToOpen(notification: Notification) { }
    
    func menuNeedsToClose(notification: Notification) {
        if let userInfo = notification.userInfo, let animated = userInfo["animated"] as? Bool, !animated {
            self.statusMenu.cancelTrackingWithoutAnimation()
        } else {
            self.statusMenu.cancelTracking()
        }
    }
    
    
    @IBAction func editRules(_ sender: AnyObject) {
        guard rulesController == nil else {
            rulesController?.window?.orderFrontRegardless()
            return
        }
        rulesController = RulesEditorWindowController.instantiate()
        rulesController?.window?.delegate = self
        rulesController?.window?.orderFrontRegardless()
    }
    
    @IBAction func showAbout(_ sender: AnyObject) {
        guard aboutController == nil else {
            aboutController?.window?.makeKeyAndOrderFront(self)
            aboutController?.window?.makeMain()
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        aboutController = AboutWindowController.instantiate()
        aboutController?.window?.delegate = self
        aboutController?.window?.makeKeyAndOrderFront(self)
        aboutController?.window?.makeMain()
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @IBAction func showPreferences(_ sender: AnyObject) {
        showPreferencesWindow()
    }

    func showPreferencesWindow() {
        guard preferencesController == nil else {
            preferencesController?.window?.makeKeyAndOrderFront(self)
            preferencesController?.window?.makeMain()
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        self.preferencesController = PreferencesWindowController.instantiate()
        preferencesController?.window?.delegate = self
        preferencesController?.window?.makeKeyAndOrderFront(self)
        preferencesController?.window?.makeMain()
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @IBAction func showRunningApps(_ sender: AnyObject) {
        guard runningAppsController == nil else {
            runningAppsController?.window?.orderFrontRegardless()
            return
        }
        runningAppsController = RunningAppWindowController.instantiate()
        runningAppsController?.window?.delegate = self
        runningAppsController?.window?.orderFrontRegardless()
    }
    
    
    @IBAction func toggleApplicationState(_ sender: NSMenuItem) {
        let disabled = sender.state == .off
        if disabled {
            setStatusImage(AppManager.default.useLightIcon ? #imageLiteral(resourceName: "LighIconDisabled") : #imageLiteral(resourceName: "IconDisabled"))
        } else {
            setStatusImage(MediaModeIcon.image(usesBackground: !AppManager.default.useLightIcon))
        }
        self.behaviorController.setApplicationIsEnabled(!disabled)
    }

    @IBAction func toggleKeyboardMode(_ sender: Any?) {
        self.behaviorController.toggleKeyboardMode()
    }
    
    @IBAction func quitApplication(_ sender: AnyObject) {
        self.stopObservingUsesLightIcon()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        self.behaviorController.performTerminationCleaning()
        NSApp.terminate(self)
    }
}
