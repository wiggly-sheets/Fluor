import Foundation
import XCTest

final class AppSettingsTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "FluorTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testStoredDefaultUsesFallbackAndPersistsChanges() {
        let setting = StoredDefault("TestValue", default: true, defaults: defaults)

        XCTAssertTrue(setting.wrappedValue)
        setting.wrappedValue = false
        XCTAssertFalse(setting.wrappedValue)
        XCTAssertEqual(defaults.object(forKey: "TestValue") as? Bool, false)
    }

    func testStoredRawDefaultRejectsUnknownRawValues() {
        let setting = StoredRawDefault("TestMode", default: FKeyMode.media, defaults: defaults)

        defaults.set(99, forKey: "TestMode")
        XCTAssertEqual(setting.wrappedValue, .media)
    }
}
