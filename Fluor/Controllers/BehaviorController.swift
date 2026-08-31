//
//  BehaviorController.swift
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
import os.log

class BehaviorController: NSObject, BehaviorDidChangeObserver, DefaultModeViewControllerDelegate, SwitchMethodDidChangeObserver, ActiveApplicationDidChangeObserver {
    @IBOutlet weak var statusMenuController: StatusMenuController!
    @IBOutlet var defaultModeViewController: DefaultModeViewController!

    @objc dynamic private var isKeySwitchCapable: Bool = false
    private var globalEventManager: Any?
    private var localEventManager: Any?
    private var fnDownTimestamp: TimeInterval?
    private var shouldHandleFNKey = false

    private let modeCoordinator = FKeyModeCoordinator()
    private var currentMode: FKeyMode = .media
    private var onLaunchKeyboardMode: FKeyMode = .media
    private var pendingMode: FKeyMode?
    private var currentAppID: String = ""
    private var currentAppURL: URL?
    private var currentAppName: String?
    private var switchMethod: SwitchMethod = .window
    private var applicationIsEnabled = true
    private var modeRequestGeneration = 0
    private var isObservingBehaviorChanges = false
    private var isObservingSwitchMethodChanges = false
    private var isObservingActiveApplicationChanges = false
    private var didPerformTerminationCleaning = false
    private var isSuspended = false

    func setupController() {
        self.onLaunchKeyboardMode = modeCoordinator.currentFKeyMode().getOrFailWith { error -> Never in
            AppErrorManager.terminateApp(withReason: error.localizedDescription)
        }
        self.currentMode = onLaunchKeyboardMode
        self.switchMethod = AppManager.default.switchMethod
        self.applicationIsEnabled = !AppManager.default.isDisabled

        applyAsObserver()

        let workspaceCenter = NSWorkspace.shared.notificationCenter
        workspaceCenter.addObserver(self, selector: #selector(appMustSleep(notification:)), name: NSWorkspace.sessionDidResignActiveNotification, object: nil)
        workspaceCenter.addObserver(self, selector: #selector(appMustSleep(notification:)), name: NSWorkspace.willSleepNotification, object: nil)
        workspaceCenter.addObserver(self, selector: #selector(appMustWake(notification:)), name: NSWorkspace.sessionDidBecomeActiveNotification, object: nil)
        workspaceCenter.addObserver(self, selector: #selector(appMustWake(notification:)), name: NSWorkspace.didWakeNotification, object: nil)

        if let currentApp = NSWorkspace.shared.frontmostApplication {
            _ = updateCurrentApplication(currentApp)
        }

        statusMenuController.setStatus(mode: currentMode, applicationIsEnabled: applicationIsEnabled)
        if applicationIsEnabled {
            adaptModeForCurrentApp()
        }
    }

    deinit {
        resignAsObserver()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    func setApplicationIsEnabled(_ enabled: Bool) {
        applicationIsEnabled = enabled
        statusMenuController.setStatus(mode: currentMode, applicationIsEnabled: enabled)

        if enabled {
            adaptModeForCurrentApp()
        } else {
            applyKeyboard(mode: onLaunchKeyboardMode, sendsModeNotification: false)
        }
    }

    func performTerminationCleaning() {
        guard !didPerformTerminationCleaning else { return }
        didPerformTerminationCleaning = true
        guard AppManager.default.shouldRestoreStateOnQuit else { return }

        let state = AppManager.default.shouldRestorePreviousState
            ? onLaunchKeyboardMode
            : AppManager.default.onQuitState

        modeRequestGeneration += 1
        if case .failure(let error) = modeCoordinator.applySynchronously(state) {
            os_log("Unable to restore FKey mode on quit: %@", type: .error, error.localizedDescription)
        }
    }

    func adaptToAccessibilityTrust() {
        if AXIsProcessTrusted() {
            isKeySwitchCapable = true
            ensureMonitoringFlagKey()
        } else {
            isKeySwitchCapable = false
            stopMonitoringFlagKey()
        }
    }

    func activeApplicationDidChange(notification: Notification) {
        adaptToAccessibilityTrust()
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
        if updateCurrentApplication(app), applicationIsEnabled {
            adaptModeForCurrentApp()
        }
    }

    func behaviorDidChangeForApp(notification: Notification) {
        guard applicationIsEnabled,
              let userInfo = notification.userInfo,
              let id = userInfo["id"] as? String,
              id == currentAppID else { return }

        let source = userInfo["source"] as? NotificationSource ?? .undefined
        let behavior = userInfo["behavior"] as? AppBehavior
        adaptModeForCurrentApp(sendsModeNotification: source != .fnKey) { [weak self] succeeded in
            guard succeeded,
                  source == .fnKey,
                  let behavior,
                  let appName = self?.currentAppName else { return }
            UserNotificationHelper.sendFKeyChangedAppBehaviorTo(behavior, appName: appName)
        }
    }

    func switchMethodDidChange(notification: Notification) {
        guard let userInfo = notification.userInfo, let method = userInfo["method"] as? SwitchMethod else { return }
        switchMethod = method
        switch method {
        case .window, .hybrid:
            startObservingBehaviorChangesIfNeeded()
            if applicationIsEnabled {
                adaptModeForCurrentApp()
            }
        case .key:
            stopObservingBehaviorChangesIfNeeded()
            if applicationIsEnabled {
                applyKeyboard(mode: AppManager.default.defaultFKeyMode)
            }
        }
    }

    func defaultModeController(_ controller: DefaultModeViewController, didChangeModeTo mode: FKeyMode) {
        guard applicationIsEnabled else { return }
        switch switchMethod {
        case .window, .hybrid:
            adaptModeForCurrentApp()
        case .key:
            applyKeyboard(mode: mode)
        }
    }

    @objc private func appMustSleep(notification: Notification) {
        guard !isSuspended else { return }
        isSuspended = true
        modeRequestGeneration += 1
        if case .failure(let error) = modeCoordinator.applySynchronously(onLaunchKeyboardMode) {
            os_log("Unable to reset FKey mode to pre-launch mode: %@", type: .error, error.localizedDescription)
        }
        resignAsObserver()
    }

    @objc private func appMustWake(notification: Notification) {
        guard isSuspended else { return }
        isSuspended = false
        applyAsObserver()
        guard applicationIsEnabled else {
            statusMenuController.setStatus(mode: currentMode, applicationIsEnabled: false)
            return
        }
        applyKeyboard(mode: currentMode, sendsModeNotification: false)
    }

    private func applyAsObserver() {
        if switchMethod != .key {
            startObservingBehaviorChangesIfNeeded()
        }
        if !isObservingSwitchMethodChanges {
            startObservingSwitchMethodDidChange()
            isObservingSwitchMethodChanges = true
        }
        if !isObservingActiveApplicationChanges {
            startObservingActiveApplicationDidChange()
            isObservingActiveApplicationChanges = true
        }
        adaptToAccessibilityTrust()
    }

    private func resignAsObserver() {
        stopObservingBehaviorChangesIfNeeded()
        if isObservingSwitchMethodChanges {
            stopObservingSwitchMethodDidChange()
            isObservingSwitchMethodChanges = false
        }
        if isObservingActiveApplicationChanges {
            stopObservingActiveApplicationDidChange()
            isObservingActiveApplicationChanges = false
        }
        stopMonitoringFlagKey()
    }

    private func startObservingBehaviorChangesIfNeeded() {
        guard !isObservingBehaviorChanges else { return }
        startObservingBehaviorDidChange()
        isObservingBehaviorChanges = true
    }

    private func stopObservingBehaviorChangesIfNeeded() {
        guard isObservingBehaviorChanges else { return }
        stopObservingBehaviorDidChange()
        isObservingBehaviorChanges = false
    }

    @discardableResult
    private func updateCurrentApplication(_ app: NSRunningApplication) -> Bool {
        guard let id = app.bundleIdentifier ?? app.executableURL?.lastPathComponent else { return false }
        currentAppID = id
        currentAppURL = app.bundleURL ?? app.executableURL
        currentAppName = app.localizedName
        return true
    }

    private func adaptModeForCurrentApp(
        sendsModeNotification: Bool = true,
        completion: ((Bool) -> Void)? = nil
    ) {
        let behavior = AppManager.default.behaviorForApp(id: currentAppID)
        let mode = KeyboardModePolicy.desiredMode(
            isDisabled: !applicationIsEnabled,
            launchMode: onLaunchKeyboardMode,
            switchMethod: switchMethod,
            appBehavior: behavior,
            defaultMode: AppManager.default.defaultFKeyMode
        )
        applyKeyboard(mode: mode, sendsModeNotification: sendsModeNotification, completion: completion)
    }

    private func applyKeyboard(
        mode: FKeyMode,
        sendsModeNotification: Bool = true,
        completion: ((Bool) -> Void)? = nil
    ) {
        pendingMode = mode
        modeRequestGeneration += 1
        let requestGeneration = modeRequestGeneration
        modeCoordinator.apply(mode) { [weak self] result in
            guard let self else { return }
            guard requestGeneration == self.modeRequestGeneration else {
                completion?(false)
                return
            }

            switch result {
            case .success(let didChange):
                self.currentMode = mode
                if self.pendingMode == mode {
                    self.pendingMode = nil
                }
                self.statusMenuController.setStatus(
                    mode: mode,
                    applicationIsEnabled: self.applicationIsEnabled
                )
                if didChange && sendsModeNotification && self.applicationIsEnabled {
                    UserNotificationHelper.sendModeChangedTo(mode)
                }
                completion?(true)
            case .failure(let error):
                if self.pendingMode == mode {
                    self.pendingMode = nil
                }
                os_log("Unable to change FKey mode: %@", type: .error, error.localizedDescription)
                AppErrorManager.showError(withReason: error.localizedDescription)
                completion?(false)
            }
        }
    }

    @discardableResult
    private func manageKeyPress(event: NSEvent) -> Bool {
        guard applicationIsEnabled else { return false }

        if event.type == .keyDown,
           AppManager.default.toggleShortcutEnabled,
           let storedKeyCode = UInt16(exactly: AppManager.default.toggleShortcutKeyCode),
           KeyboardShortcut(
                keyCode: storedKeyCode,
                modifiers: NSEvent.ModifierFlags(rawValue: UInt(AppManager.default.toggleShortcutModifiers))
           ).matches(
                keyCode: event.keyCode,
                modifiers: event.modifierFlags,
                isRepeat: event.isARepeat
           ) {
            toggleKeyboardMode()
            return true
        }

        guard switchMethod != .window else { return false }
        if event.type == .flagsChanged {
            if event.modifierFlags.contains(.function) {
                if event.keyCode == 63 {
                    fnDownTimestamp = event.timestamp
                    shouldHandleFNKey = true
                } else {
                    fnDownTimestamp = nil
                    shouldHandleFNKey = false
                }
            } else {
                if shouldHandleFNKey, let timestamp = fnDownTimestamp {
                    let delta = (event.timestamp - timestamp) * 1000
                    shouldHandleFNKey = false
                    if event.keyCode == 63, delta <= AppManager.default.fnKeyMaximumDelay {
                        switch switchMethod {
                        case .key:
                            fnKeyPressedImpactsGlobal()
                        case .hybrid:
                            fnKeyPressedImpactsApp()
                        default:
                            return false
                        }
                    }
                }
            }
        } else if shouldHandleFNKey {
            shouldHandleFNKey = false
            fnDownTimestamp = nil
        }
        return false
    }

    func toggleKeyboardMode() {
        guard applicationIsEnabled else { return }
        let mode = (pendingMode ?? currentMode).counterPart
        applyKeyboard(mode: mode)
    }

    private func fnKeyPressedImpactsGlobal() {
        let mode = (pendingMode ?? currentMode).counterPart
        applyKeyboard(mode: mode, sendsModeNotification: false) { succeeded in
            guard succeeded else { return }
            AppManager.default.defaultFKeyMode = mode
            UserNotificationHelper.sendGlobalModeChangedTo(mode)
        }
    }

    private func fnKeyPressedImpactsApp() {
        guard applicationIsEnabled, let url = currentAppURL else {
            os_log("Ignoring Fn key because the active application could not be identified", type: .error)
            return
        }
        let appBehavior = AppManager.default.behaviorForApp(id: currentAppID)
        let defaultBehavior = AppManager.default.defaultFKeyMode.behavior
        let newAppBehavior: AppBehavior

        switch appBehavior {
        case .inferred:
            newAppBehavior = defaultBehavior.counterPart
        case defaultBehavior.counterPart:
            newAppBehavior = defaultBehavior
        case defaultBehavior:
            newAppBehavior = .inferred
        default:
            newAppBehavior = .inferred
        }

        AppManager.default.propagate(behavior: newAppBehavior, forApp: currentAppID, at: url, from: .fnKey)
    }

    private func ensureMonitoringFlagKey() {
        guard isKeySwitchCapable else { return }
        if globalEventManager == nil {
            globalEventManager = NSEvent.addGlobalMonitorForEvents(
                matching: [.flagsChanged, .keyDown]
            ) { [weak self] event in
                _ = self?.manageKeyPress(event: event)
            }
        }
        if localEventManager == nil {
            localEventManager = NSEvent.addLocalMonitorForEvents(
                matching: [.flagsChanged, .keyDown]
            ) { [weak self] event in
                if NSApp.keyWindow?.firstResponder is HotkeyRecorderButton {
                    return event
                }
                self?.manageKeyPress(event: event) == true ? nil : event
            }
        }
    }

    private func stopMonitoringFlagKey() {
        shouldHandleFNKey = false
        fnDownTimestamp = nil
        if let gem = globalEventManager {
            NSEvent.removeMonitor(gem)
            globalEventManager = nil
        }
        if let lem = localEventManager {
            NSEvent.removeMonitor(lem)
            localEventManager = nil
        }
    }
}
