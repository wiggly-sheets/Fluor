import XCTest

final class KeyboardModePolicyTests: XCTestCase {
    func testDisabledApplicationAlwaysRestoresLaunchMode() {
        for method in [SwitchMethod.window, .hybrid, .key] {
            for behavior in [AppBehavior.inferred, .media, .function] {
                XCTAssertEqual(
                    KeyboardModePolicy.desiredMode(
                        isDisabled: true,
                        launchMode: .function,
                        switchMethod: method,
                        appBehavior: behavior,
                        defaultMode: .media
                    ),
                    .function
                )
            }
        }
    }

    func testKeySwitchingUsesDefaultMode() {
        for behavior in [AppBehavior.inferred, .media, .function] {
            XCTAssertEqual(
                KeyboardModePolicy.desiredMode(
                    isDisabled: false,
                    launchMode: .media,
                    switchMethod: .key,
                    appBehavior: behavior,
                    defaultMode: .function
                ),
                .function
            )
        }
    }

    func testApplicationSwitchingResolvesRulesAndDefault() {
        for method in [SwitchMethod.window, .hybrid] {
            XCTAssertEqual(desiredMode(method: method, behavior: .inferred), .function)
            XCTAssertEqual(desiredMode(method: method, behavior: .media), .media)
            XCTAssertEqual(desiredMode(method: method, behavior: .function), .function)
        }
    }

    private func desiredMode(method: SwitchMethod, behavior: AppBehavior) -> FKeyMode {
        KeyboardModePolicy.desiredMode(
            isDisabled: false,
            launchMode: .media,
            switchMethod: method,
            appBehavior: behavior,
            defaultMode: .function
        )
    }
}
