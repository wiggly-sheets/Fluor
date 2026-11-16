import XCTest
#if SWIFT_PACKAGE
@testable import Fluor
#endif

final class UserNotificationEnablementTests: XCTestCase {
    func testAllIncludesEveryNotificationCategory() {
        XCTAssertTrue(UserNotificationEnablement.all.contains(.appSwitch))
        XCTAssertTrue(UserNotificationEnablement.all.contains(.appKey))
        XCTAssertTrue(UserNotificationEnablement.all.contains(.globalKey))
    }
}
