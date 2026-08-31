import AppKit

struct KeyboardShortcut: Equatable {
    static let supportedModifiers: NSEvent.ModifierFlags = [.command, .option, .control, .shift]

    let keyCode: UInt16
    let modifiers: NSEvent.ModifierFlags

    init(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) {
        self.keyCode = keyCode
        self.modifiers = Self.normalizedModifiers(modifiers)
    }

    static func normalizedModifiers(_ modifiers: NSEvent.ModifierFlags) -> NSEvent.ModifierFlags {
        modifiers.intersection(supportedModifiers)
    }

    func matches(keyCode: UInt16, modifiers: NSEvent.ModifierFlags, isRepeat: Bool) -> Bool {
        !isRepeat
            && self.keyCode == keyCode
            && self.modifiers == Self.normalizedModifiers(modifiers)
    }
}
