//
//  HotkeyRecorderButton.swift
//  Fluor
//

import Cocoa

final class HotkeyRecorderButton: NSButton {
    private var isRecording = false

    override func awakeFromNib() {
        super.awakeFromNib()
        updateTitle()
    }

    override func mouseDown(with event: NSEvent) {
        isRecording = true
        title = NSLocalizedString("Press shortcut…", comment: "")
        window?.makeFirstResponder(self)
    }

    override func resignFirstResponder() -> Bool {
        let didResign = super.resignFirstResponder()
        if didResign && isRecording {
            isRecording = false
            updateTitle()
        }
        return didResign
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }

        if event.keyCode == 53 { // Escape
            finishRecording()
            return
        }

        let modifiers = KeyboardShortcut.normalizedModifiers(event.modifierFlags)
        guard modifiers.intersection([.command, .option, .control]) != [] else {
            NSSound.beep()
            return
        }

        AppManager.default.toggleShortcutKeyCode = Int(event.keyCode)
        AppManager.default.toggleShortcutModifiers = Int(modifiers.rawValue)
        AppManager.default.toggleShortcutDisplay = shortcutDisplay(for: event, modifiers: modifiers)
        AppManager.default.toggleShortcutEnabled = true
        finishRecording()
    }

    @IBAction func clearShortcut(_ sender: Any?) {
        isRecording = false
        AppManager.default.toggleShortcutEnabled = false
        updateTitle()
    }

    override func cancelOperation(_ sender: Any?) {
        if isRecording {
            finishRecording()
        } else {
            super.cancelOperation(sender)
        }
    }

    private func finishRecording() {
        isRecording = false
        updateTitle()
        window?.makeFirstResponder(nil)
    }

    private func updateTitle() {
        title = AppManager.default.toggleShortcutEnabled
            ? AppManager.default.toggleShortcutDisplay
            : NSLocalizedString("Set shortcut", comment: "")
    }

    private func shortcutDisplay(for event: NSEvent, modifiers: NSEvent.ModifierFlags) -> String {
        var display = ""
        if modifiers.contains(.control) { display += "⌃" }
        if modifiers.contains(.option) { display += "⌥" }
        if modifiers.contains(.shift) { display += "⇧" }
        if modifiers.contains(.command) { display += "⌘" }
        return display + (event.charactersIgnoringModifiers?.uppercased() ?? "Key \(event.keyCode)")
    }
}
