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
import DefaultsWrapper

extension UserDefaultsKeyName {
    static let userHasAlreadyAnsweredAccessibility: UserDefaultsKeyName = "HasAlreadyRefusedAccessibility"
    static let keyboardMode: UserDefaultsKeyName = "DefaultKeyboardMode"
    static let appRules: UserDefaultsKeyName = "AppRules"
    static let restoreStateOnQuit: UserDefaultsKeyName = "ResetModeOnQuit"
    static let restoreStateAsBeforeStartup: UserDefaultsKeyName = "SameStateAsBeforeStartup"
    static let onQuitState: UserDefaultsKeyName = "OnQuitState"
    static let disabledOnLunch: UserDefaultsKeyName = "OnLaunchDisabled"
    static let switchMethod: UserDefaultsKeyName = "DefaultSwitchMethod"
    static let useLightIcon: UserDefaultsKeyName = "UseLightIcon"
    static let showAllRunningProcesses: UserDefaultsKeyName = "ShowAllProcesses"
    static let fnKeyMaximumDelay: UserDefaultsKeyName = "FNKeyReleaseMaximumDelay"
    static let lastRunVersion: UserDefaultsKeyName = "LastRunVersion"
    static let hideSwitchMethod: UserDefaultsKeyName = "HideSwitchMethod"
    static let sendFnKeyNotification: UserDefaultsKeyName = "sendFnKeyNotification"
    static let hideNotificationAuthorizationPopup: UserDefaultsKeyName = "hideNotificationAuthorizationPopup"
    static let userNotificationEnablement: UserDefaultsKeyName = "userNotificationEnablement"
    static let sendLegacyUserNotifications: UserDefaultsKeyName = "sendLegacyUserNotification"
    static let toggleShortcutKeyCode: UserDefaultsKeyName = "ToggleShortcutKeyCode"
    static let toggleShortcutModifiers: UserDefaultsKeyName = "ToggleShortcutModifiers"
    static let toggleShortcutDisplay: UserDefaultsKeyName = "ToggleShortcutDisplay"
    static let migratedTahoePreferences: UserDefaultsKeyName = "MigratedTahoePreferences"
    static let hideMenuBarItem: UserDefaultsKeyName = "HideMenuBarItem"
    static let toggleShortcutEnabled: UserDefaultsKeyName = "ToggleShortcutEnabled"
}

class AppManager: BehaviorDidChangePoster {
    
    static let `default`: AppManager = AppManager()
    
    @Defaults(key: .keyboardMode, defaultValue: .media)
    var defaultFKeyMode: FKeyMode
    
    @Defaults(key: .switchMethod, defaultValue: .window)
    var switchMethod: SwitchMethod
    
    @Defaults(key: .hideSwitchMethod, defaultValue: false)
    var hideSwitchMethod: Bool
    
    @Defaults(key: .lastRunVersion, defaultValue: "unknown")
    var lastRunVersion: String
    
    @Defaults(key: .restoreStateOnQuit, defaultValue: false)
    var shouldRestoreStateOnQuit: Bool
    
    @Defaults(key: .restoreStateAsBeforeStartup, defaultValue: false)
    var shouldRestorePreviousState: Bool 
    
    @Defaults(key: .onQuitState, defaultValue: .media)
    var onQuitState: FKeyMode
    
    @Defaults(key: .disabledOnLunch, defaultValue: false)
    var isDisabled: Bool
    
    @Defaults(key: .useLightIcon, defaultValue: false)
    var useLightIcon: Bool
    
    @Defaults(key: .showAllRunningProcesses, defaultValue: false)
    var showAllRunningProcesses: Bool
    
    @Defaults(key: .userHasAlreadyAnsweredAccessibility, defaultValue: false)
    var hasAlreadyAnsweredAccessibility: Bool 
    
    @Defaults(key: .fnKeyMaximumDelay, defaultValue: 280)
    var fnKeyMaximumDelay: TimeInterval
    
    @Defaults(key: .hideNotificationAuthorizationPopup, defaultValue: false)
    var hideNotificationAuthorizationPopup: Bool
    
    @Defaults(key: .sendFnKeyNotification, defaultValue: true)
    var sendFnKeyNotification: Bool
    
    @Defaults(key: .userNotificationEnablement, defaultValue: .none)
    var userNotificationEnablement: UserNotificationEnablement
    
    @Defaults(key: .sendLegacyUserNotifications, defaultValue: false)
    var sendLegacyUserNotifications: Bool

    @Defaults(key: .toggleShortcutKeyCode, defaultValue: 3)
    var toggleShortcutKeyCode: Int

    @Defaults(key: .toggleShortcutModifiers, defaultValue: 1_835_008)
    var toggleShortcutModifiers: Int

    @Defaults(key: .toggleShortcutDisplay, defaultValue: "⌃⌥⌘F")
    var toggleShortcutDisplay: String

    @Defaults(key: .hideMenuBarItem, defaultValue: false)
    var hideMenuBarItem: Bool

    @Defaults(key: .toggleShortcutEnabled, defaultValue: true)
    var toggleShortcutEnabled: Bool
    
    private(set) var rules: Set<Rule> = []
    private var behaviorDict: [String: AppBehavior] = [:]
    private let defaults = UserDefaults.standard
    
    private init() {
        self.migrateTahoePreferencesIfNeeded()
        self.loadRules()
    }

    private func migrateTahoePreferencesIfNeeded() {
        guard !defaults.bool(forKey: UserDefaultsKeyName.migratedTahoePreferences.rawValue) else { return }
        defer { defaults.set(true, forKey: UserDefaultsKeyName.migratedTahoePreferences.rawValue) }

        guard let legacyDefaults = UserDefaults(suiteName: "com.pyrolyse.FluorTahoe")?.persistentDomain(forName: "com.pyrolyse.FluorTahoe") else { return }

        for (key, value) in legacyDefaults where defaults.object(forKey: key) == nil {
            defaults.set(value, forKey: key)
        }
        defaults.set(true, forKey: UserDefaultsKeyName.migratedTahoePreferences.rawValue)
    }
    
    func propagate(behavior: AppBehavior, forApp id: String, at url: URL, from source: NotificationSource) {
        guard self.behaviorDict[id] != behavior else { return }
        self.setBehaviorForApp(id: id, behavior: behavior, url: url)
        self.postBehaviorDidChangeNotification(id: id, url: url, behavior: behavior, source: source)
    }
    
    func behaviorForApp(id: String) -> AppBehavior {
        return behaviorDict[id] ?? .inferred
    }
    
    
    func setBehaviorForApp(id: String, behavior: AppBehavior, url: URL) {
        var change = false
        if behavior == .inferred {
            self.behaviorDict.removeValue(forKey: id)
            guard let index = self.rules.firstIndex(where: { $0.url == url }) else { fatalError() }
            self.rules.remove(at: index)
            change = true
        } else if let previousBehavior = self.behaviorDict[id] {
            if previousBehavior != behavior {
                self.behaviorDict[id] = behavior
                guard let rule = self.rules.first(where: { $0.url == url }) else { fatalError() }
                rule.behavior = behavior
                change = true
            }
        } else {
            behaviorDict[id] = behavior
            self.rules.insert(.init(id: id, url: url, behavior: behavior))
            change = true
        }
        if change { synchronizeRules() }
    }
    
    
    func getCurrentFKeyMode() -> FKeyMode {
        FKeyManager.getCurrentFKeyMode().getOrFailWith { (error) -> Never in
            AppErrorManager.terminateApp(withReason: error.localizedDescription)
        }
    }
    
    
    func keyboardStateFor(behavior: AppBehavior) -> FKeyMode {
        switch behavior {
        case .inferred:
            return self.defaultFKeyMode
        case .media:
            return .media
        case .function:
            return .function
        }
    }
    
    private func loadRules() {
        if let rules: Set<Rule> = self.defaults.convertible(forKey: UserDefaultsKeyName.appRules.rawValue) {
            self.rules = rules
            self.behaviorDict = .init(uniqueKeysWithValues: rules.map { ($0.id, $0.behavior) })
        }
    }
    
    private func synchronizeRules() {
        self.defaults.set(self.rules, forKey: UserDefaultsKeyName.appRules.rawValue)
    }
}
