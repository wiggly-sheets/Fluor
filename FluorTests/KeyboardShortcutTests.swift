import AppKit
import XCTest

final class KeyboardShortcutTests: XCTestCase {
    func testMatchingIgnoresIncidentalSystemFlags() {
        let shortcut = KeyboardShortcut(
            keyCode: 3,
            modifiers: [.control, .option, .command]
        )

        XCTAssertTrue(
            shortcut.matches(
                keyCode: 3,
                modifiers: [.control, .option, .command, .capsLock, .numericPad, .function],
                isRepeat: false
            )
        )
    }

    func testMatchingRejectsRepeatsAndDifferentInput() {
        let shortcut = KeyboardShortcut(keyCode: 3, modifiers: [.command, .shift])

        XCTAssertFalse(shortcut.matches(keyCode: 3, modifiers: [.command, .shift], isRepeat: true))
        XCTAssertFalse(shortcut.matches(keyCode: 4, modifiers: [.command, .shift], isRepeat: false))
        XCTAssertFalse(shortcut.matches(keyCode: 3, modifiers: [.command], isRepeat: false))
    }

    func testInitializerNormalizesModifiers() {
        let shortcut = KeyboardShortcut(
            keyCode: 3,
            modifiers: [.command, .option, .capsLock, .numericPad, .function]
        )

        XCTAssertEqual(shortcut.modifiers, [.command, .option])
    }
}
