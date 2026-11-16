import XCTest
#if SWIFT_PACKAGE
@testable import Fluor
#endif

final class PreferenceMigrationTests: XCTestCase {
    func testCurrentValuesWinAndLegacyDomainsUsePriorityOrder() {
        let values = PreferenceMigration.valuesToMigrate(
            currentDomain: [SettingsKey.keyboardMode: FKeyMode.function.rawValue],
            legacyDomains: [
                [
                    SettingsKey.keyboardMode: FKeyMode.media.rawValue,
                    "Shared": "Tahoe",
                    "TahoeOnly": true
                ],
                [
                    "Shared": "Original",
                    "OriginalOnly": true
                ]
            ]
        )

        XCTAssertNil(values[SettingsKey.keyboardMode])
        XCTAssertEqual(values["Shared"] as? String, "Tahoe")
        XCTAssertEqual(values["TahoeOnly"] as? Bool, true)
        XCTAssertEqual(values["OriginalOnly"] as? Bool, true)
    }

    func testMigrationExcludesMachineSpecificAndAccessibilityValues() {
        let values = PreferenceMigration.valuesToMigrate(
            currentDomain: [:],
            legacyDomains: [[
                "NSStatusItem Visible FluorStatusItem": false,
                SettingsKey.userHasAlreadyAnsweredAccessibility: true,
                SettingsKey.switchMethod: SwitchMethod.hybrid.rawValue
            ]]
        )

        XCTAssertNil(values["NSStatusItem Visible FluorStatusItem"])
        XCTAssertNil(values[SettingsKey.userHasAlreadyAnsweredAccessibility])
        XCTAssertEqual(values[SettingsKey.switchMethod] as? Int, SwitchMethod.hybrid.rawValue)
    }

    func testLegacyDomainsListNewestBundleFirst() {
        let domains = PreferenceMigration.legacyDomainNames

        XCTAssertEqual(domains.count, 2)
        XCTAssertEqual(domains.first, "com.pyrolyse.FluorTahoe")
        XCTAssertEqual(domains.last, "com.pyrolyse.Fluor")
    }
}
