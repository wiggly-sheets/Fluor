import Foundation

enum SettingsKey {
    static let userHasAlreadyAnsweredAccessibility = "HasAlreadyRefusedAccessibility"
    static let keyboardMode = "DefaultKeyboardMode"
    static let appRules = "AppRules"
    static let restoreStateOnQuit = "ResetModeOnQuit"
    static let restoreStateAsBeforeStartup = "SameStateAsBeforeStartup"
    static let onQuitState = "OnQuitState"
    static let disabledOnLaunch = "OnLaunchDisabled"
    static let switchMethod = "DefaultSwitchMethod"
    static let useLightIcon = "UseLightIcon"
    static let showAllRunningProcesses = "ShowAllProcesses"
    static let fnKeyMaximumDelay = "FNKeyReleaseMaximumDelay"
    static let hideSwitchMethod = "HideSwitchMethod"
    static let hideNotificationAuthorizationPopup = "hideNotificationAuthorizationPopup"
    static let userNotificationEnablement = "userNotificationEnablement"
    static let toggleShortcutKeyCode = "ToggleShortcutKeyCode"
    static let toggleShortcutModifiers = "ToggleShortcutModifiers"
    static let toggleShortcutDisplay = "ToggleShortcutDisplay"
    static let migratedLegacyPreferencesV2 = "MigratedLegacyPreferencesV2"
    static let hideMenuBarItem = "HideMenuBarItem"
    static let toggleShortcutEnabled = "ToggleShortcutEnabled"
}

@propertyWrapper
struct StoredDefault<Value> {
    private let key: String
    private let defaultValue: Value
    private let defaults: UserDefaults

    init(_ key: String, default defaultValue: Value, defaults: UserDefaults = .standard) {
        self.key = key
        self.defaultValue = defaultValue
        self.defaults = defaults
        defaults.register(defaults: [key: defaultValue])
    }

    var wrappedValue: Value {
        get { defaults.object(forKey: key) as? Value ?? defaultValue }
        nonmutating set { defaults.set(newValue, forKey: key) }
    }
}

@propertyWrapper
struct StoredRawDefault<Value: RawRepresentable> where Value.RawValue == Int {
    private let key: String
    private let defaultValue: Value
    private let defaults: UserDefaults

    init(_ key: String, default defaultValue: Value, defaults: UserDefaults = .standard) {
        self.key = key
        self.defaultValue = defaultValue
        self.defaults = defaults
        defaults.register(defaults: [key: defaultValue.rawValue])
    }

    var wrappedValue: Value {
        get {
            guard defaults.object(forKey: key) != nil else { return defaultValue }
            return Value(rawValue: defaults.integer(forKey: key)) ?? defaultValue
        }
        nonmutating set { defaults.set(newValue.rawValue, forKey: key) }
    }
}
