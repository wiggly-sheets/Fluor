import XCTest

final class UserNotificationEnablementTests: XCTestCase {
    func testAllContainsEveryNotificationCategory() {
        XCTAssertTrue(UserNotificationEnablement.all.contains(.appSwitch))
        XCTAssertTrue(UserNotificationEnablement.all.contains(.appKey))
        XCTAssertTrue(UserNotificationEnablement.all.contains(.globalKey))
    }

    func testCategoriesCanBePersistedAsRawValue() {
        let selection: UserNotificationEnablement = [.appSwitch, .globalKey]
        let restored = UserNotificationEnablement(rawValue: selection.rawValue)

        XCTAssertEqual(restored, selection)
        XCTAssertFalse(restored.contains(.appKey))
    }
}
