import XCTest
#if SWIFT_PACKAGE
@testable import Fluor
#endif

final class KeyboardModePolicyTests: XCTestCase {
    func testDisabledApplicationRestoresLaunchModeInsteadOfConfiguredMode() {
        XCTAssertEqual(
            KeyboardModePolicy.desiredMode(
                isDisabled: true,
                launchMode: .media,
                switchMethod: .key,
                appBehavior: .function,
                defaultMode: .function
            ),
            .media
        )
    }

    func testKeySwitchingUsesDefaultMode() {
        XCTAssertEqual(
            KeyboardModePolicy.desiredMode(
                isDisabled: false,
                launchMode: .media,
                switchMethod: .key,
                appBehavior: .media,
                defaultMode: .function
            ),
            .function
        )
    }

    func testWindowSwitchingUsesApplicationBehavior() {
        XCTAssertEqual(desiredMode(behavior: .inferred), .function)
        XCTAssertEqual(desiredMode(behavior: .media), .media)
        XCTAssertEqual(desiredMode(behavior: .function), .function)
    }

    private func desiredMode(behavior: AppBehavior) -> FKeyMode {
        KeyboardModePolicy.desiredMode(
            isDisabled: false,
            launchMode: .media,
            switchMethod: .window,
            appBehavior: behavior,
            defaultMode: .function
        )
    }
}
