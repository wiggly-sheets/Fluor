import XCTest
#if SWIFT_PACKAGE
@testable import Fluor
#endif

final class MenuBarItemHidingModeTests: XCTestCase {
    func testAlwaysHidesInEveryMode() {
        XCTAssertTrue(MenuBarItemHidingMode.always.hides(for: .media))
        XCTAssertTrue(MenuBarItemHidingMode.always.hides(for: .function))
    }

    func testModeSpecificHidingOnlyMatchesItsMode() {
        XCTAssertTrue(MenuBarItemHidingMode.media.hides(for: .media))
        XCTAssertFalse(MenuBarItemHidingMode.media.hides(for: .function))
        XCTAssertFalse(MenuBarItemHidingMode.function.hides(for: .media))
        XCTAssertTrue(MenuBarItemHidingMode.function.hides(for: .function))
    }
}
