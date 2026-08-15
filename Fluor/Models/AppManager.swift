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
    
    @StoredDefault(SettingsKey.lastRunVersion, default: "unknown")
    var lastRunVersion: String
    
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
    
    @StoredDefault(SettingsKey.userHasAlreadyAnsweredAccessibility, default: false)
    var hasAlreadyAnsweredAccessibility: Bool 
    
    @StoredDefault(SettingsKey.fnKeyMaximumDelay, default: 280)
    var fnKeyMaximumDelay: TimeInterval
    
    @StoredDefault(SettingsKey.hideNotificationAuthorizationPopup, default: false)
    var hideNotificationAuthorizationPopup: Bool
    
    @StoredDefault(SettingsKey.sendFnKeyNotification, default: true)
    var sendFnKeyNotification: Bool
    
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
    
    private(set) var rules: Set<Rule> = []
    private var behaviorDict: [String: AppBehavior] = [:]
    private let defaults = UserDefaults.standard
    
    private init() {
        self.migrateTahoePreferencesIfNeeded()
        self.loadRules()
    }

    private func migrateTahoePreferencesIfNeeded() {
        guard !defaults.bool(forKey: SettingsKey.migratedTahoePreferences) else { return }
        defer { defaults.set(true, forKey: SettingsKey.migratedTahoePreferences) }

        guard let legacyDefaults = UserDefaults(suiteName: "com.pyrolyse.FluorTahoe")?.persistentDomain(forName: "com.pyrolyse.FluorTahoe") else { return }
        let currentDomainName = Bundle.main.bundleIdentifier ?? ""
        let currentDefaults = defaults.persistentDomain(forName: currentDomainName) ?? [:]

        let excludedKeys: Set<String> = [
            "HasAlreadyRefusedAccessibility"
        ]

        for (key, value) in legacyDefaults
        where !key.hasPrefix("NSStatusItem ")
            && !excludedKeys.contains(key)
            && currentDefaults[key] == nil {
            defaults.set(value, forKey: key)
        }
        defaults.set(true, forKey: SettingsKey.migratedTahoePreferences)
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
        let storedRules = defaults.array(forKey: SettingsKey.appRules) as? [[String: Any]] ?? []
        let rules = Set(storedRules.compactMap(Rule.init(storedValue:)))
        self.rules = rules
        self.behaviorDict = .init(uniqueKeysWithValues: rules.map { ($0.id, $0.behavior) })
    }
    
    private func synchronizeRules() {
        defaults.set(rules.map(\.storedValue), forKey: SettingsKey.appRules)
    }
}
