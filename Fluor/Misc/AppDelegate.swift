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
    // Main.xib creates the delegate as a top-level object, while
    // NSApplication.delegate is non-owning. Retain that legacy nib-created
    // delegate for the lifetime of the application.
    private static var retainedInstance: AppDelegate?

    let statusMenuController: StatusMenuController = .init()
    private var mainMenuTopLevelObjects: [Any] = []
    private var ongoingMenuBarActivity: NSObjectProtocol?
    private let legacyPreferencesMigrationKey = "DidMigrateLegacyFluorPreferences"

    override func awakeFromNib() {
        super.awakeFromNib()
        AppDelegate.retainedInstance = self
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        migrateLegacyPreferences()

        DispatchQueue.main.async { [weak self] in
            let processInfo = ProcessInfo.processInfo
            processInfo.automaticTerminationSupportEnabled = true
            self?.ongoingMenuBarActivity = processInfo.beginActivity(
                options: .automaticTerminationDisabled,
                reason: "Fluor provides ongoing menu bar functionality"
            )
        }

        ValueTransformer.setValueTransformer(RuleValueTransformer(), forName: NSValueTransformerName("RuleValueTransformer"))
        
        // Check accessibility
        if !AXIsProcessTrusted() && !AppManager.default.hasAlreadyAnsweredAccessibility {
            let options : NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true]
            AXIsProcessTrustedWithOptions(options)
            AppManager.default.hasAlreadyAnsweredAccessibility = true
        }
        
        if AppManager.default.lastRunVersion != self.getBundleVersion() {
            AppManager.default.lastRunVersion = self.getBundleVersion()
        }
        
        UserNotificationHelper.askUserAtLaunch()
        
        self.loadMainMenu()
    }

    /// The Tahoe build uses a fresh bundle identity because menu-bar managers
    /// can persist a bundle-wide hidden state for the abandoned release. Keep
    /// the user's rules and behavior settings, but let macOS request a fresh
    /// accessibility grant and never import the stale status-item placement.
    private func migrateLegacyPreferences() {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: legacyPreferencesMigrationKey) == nil else { return }

        let excludedKeys: Set<String> = [
            "HasAlreadyRefusedAccessibility"
        ]
        let legacyDomain = defaults.persistentDomain(forName: "com.pyrolyse.Fluor") ?? [:]

        for (key, value) in legacyDomain
        where !key.hasPrefix("NSStatusItem ") && !excludedKeys.contains(key) {
            if defaults.object(forKey: key) == nil {
                defaults.set(value, forKey: key)
            }
        }

        defaults.set(true, forKey: legacyPreferencesMigrationKey)
    }
    
    private func loadMainMenu() {
        guard self.mainMenuTopLevelObjects.isEmpty else { return }
        let nib = NSNib(nibNamed: "MainMenu", bundle: nil)
        var topLevelObjects: NSArray?
        nib?.instantiate(withOwner: self.statusMenuController, topLevelObjects: &topLevelObjects)
        self.mainMenuTopLevelObjects = topLevelObjects as? [Any] ?? []
    }
    
    private func getBundleVersion() -> String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as! String
    }
    
    func windowWillClose(_ notification: Notification) {
        self.loadMainMenu()
    }
}
