//
//  AppManager.swift
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

class AppManager: BehaviorDidChangePoster {
    
    static let `default`: AppManager = AppManager()
    
    @StoredRawDefault(SettingsKey.keyboardMode, default: .media)
    var defaultFKeyMode: FKeyMode
    
    @StoredRawDefault(SettingsKey.switchMethod, default: .window)
    var switchMethod: SwitchMethod
    
    @StoredDefault(SettingsKey.hideSwitchMethod, default: false)
    var hideSwitchMethod: Bool
    
    @StoredDefault(SettingsKey.restoreStateOnQuit, default: false)
    var shouldRestoreStateOnQuit: Bool
    
    @StoredDefault(SettingsKey.restoreStateAsBeforeStartup, default: false)
    var shouldRestorePreviousState: Bool 
    
    @StoredRawDefault(SettingsKey.onQuitState, default: .media)
    var onQuitState: FKeyMode
    
    @StoredDefault(SettingsKey.disabledOnLaunch, default: false)
    var isDisabled: Bool
    
    @StoredDefault(SettingsKey.useLightIcon, default: false)
    var useLightIcon: Bool
    
    @StoredDefault(SettingsKey.showAllRunningProcesses, default: false)
    var showAllRunningProcesses: Bool
    
    @StoredDefault(SettingsKey.fnKeyMaximumDelay, default: 280)
    var fnKeyMaximumDelay: TimeInterval
    
    @StoredDefault(SettingsKey.hideNotificationAuthorizationPopup, default: false)
    var hideNotificationAuthorizationPopup: Bool
    
    @StoredRawDefault(SettingsKey.userNotificationEnablement, default: .none)
    var userNotificationEnablement: UserNotificationEnablement

    @StoredDefault(SettingsKey.toggleShortcutKeyCode, default: 3)
    var toggleShortcutKeyCode: Int

    @StoredDefault(SettingsKey.toggleShortcutModifiers, default: 1_835_008)
    var toggleShortcutModifiers: Int

    @StoredDefault(SettingsKey.toggleShortcutDisplay, default: "⌃⌥⌘F")
    var toggleShortcutDisplay: String

    @StoredDefault(SettingsKey.hideMenuBarItem, default: false)
    var hideMenuBarItem: Bool

    @StoredDefault(SettingsKey.toggleShortcutEnabled, default: true)
    var toggleShortcutEnabled: Bool
    
    var rules: Set<Rule> {
        Set(ruleRegistry.records.map { Rule(record: $0) })
    }

    private var ruleRegistry = RuleRegistry()
    private let defaults = UserDefaults.standard
    
    private init() {
        self.migrateLegacyPreferencesIfNeeded()
        self.loadRules()
    }

    private func migrateLegacyPreferencesIfNeeded() {
        guard !defaults.bool(forKey: SettingsKey.migratedLegacyPreferencesV2) else { return }
        let currentDomainName = Bundle.main.bundleIdentifier ?? ""
        let currentDefaults = defaults.persistentDomain(forName: currentDomainName) ?? [:]

        let legacyDomains = PreferenceMigration.legacyDomainNames.compactMap(defaults.persistentDomain(forName:))
        let migratedValues = PreferenceMigration.valuesToMigrate(
            currentDomain: currentDefaults,
            legacyDomains: legacyDomains
        )

        for (key, value) in migratedValues {
            defaults.set(value, forKey: key)
        }
        defaults.set(true, forKey: SettingsKey.migratedLegacyPreferencesV2)
    }
    
    func propagate(behavior: AppBehavior, forApp id: String, at url: URL, from source: NotificationSource) {
        guard ruleRegistry.setBehavior(behavior, for: id, at: url) else { return }
        synchronizeRules()
        self.postBehaviorDidChangeNotification(id: id, url: url, behavior: behavior, source: source)
    }
    
    func behaviorForApp(id: String) -> AppBehavior {
        ruleRegistry.behavior(for: id)
    }
    private func loadRules() {
        let storedRules = defaults.array(forKey: SettingsKey.appRules) as? [[String: Any]] ?? []
        ruleRegistry = RuleRegistry(storedValues: storedRules)
    }
    
    private func synchronizeRules() {
        defaults.set(ruleRegistry.storedValues, forKey: SettingsKey.appRules)
    }
}
