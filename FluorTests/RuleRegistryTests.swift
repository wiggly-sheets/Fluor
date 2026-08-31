import Foundation
import XCTest

final class RuleRegistryTests: XCTestCase {
    func testMalformedAndInferredStoredRulesAreDiscarded() {
        let registry = RuleRegistry(storedValues: [
            ["id": "missing-path", "behavior": AppBehavior.media.rawValue],
            ["id": "inferred", "path": "/Applications/A.app", "behavior": AppBehavior.inferred.rawValue],
            ["id": "valid", "path": "/Applications/B.app", "behavior": AppBehavior.function.rawValue]
        ])

        XCTAssertEqual(registry.records.map(\.id), ["valid"])
        XCTAssertEqual(registry.behavior(for: "valid"), .function)
    }

    func testDuplicateStoredRulesAreDeduplicatedByBundleIdentifier() {
        let registry = RuleRegistry(storedValues: [
            ["id": "com.example.App", "path": "/Applications/Old.app", "behavior": AppBehavior.media.rawValue],
            ["id": "com.example.App", "path": "/Applications/New.app", "behavior": AppBehavior.function.rawValue]
        ])

        XCTAssertEqual(registry.records.count, 1)
        XCTAssertEqual(registry.records.first?.url.path, "/Applications/New.app")
        XCTAssertEqual(registry.behavior(for: "com.example.App"), .function)
    }

    func testUpdatingRuleRefreshesMovedApplicationURL() {
        var registry = RuleRegistry()
        let oldURL = URL(fileURLWithPath: "/Applications/Old.app")
        let newURL = URL(fileURLWithPath: "/Applications/New.app")

        XCTAssertTrue(registry.setBehavior(.media, for: "com.example.App", at: oldURL))
        XCTAssertFalse(registry.setBehavior(.media, for: "com.example.App", at: oldURL))
        XCTAssertTrue(registry.setBehavior(.media, for: "com.example.App", at: newURL))
        XCTAssertEqual(registry.records.first?.url, newURL)
    }

    func testInferredBehaviorRemovesRule() {
        var registry = RuleRegistry()
        let url = URL(fileURLWithPath: "/Applications/App.app")

        XCTAssertFalse(registry.setBehavior(.inferred, for: "com.example.App", at: url))
        XCTAssertTrue(registry.setBehavior(.function, for: "com.example.App", at: url))
        XCTAssertTrue(registry.setBehavior(.inferred, for: "com.example.App", at: url))
        XCTAssertEqual(registry.behavior(for: "com.example.App"), .inferred)
        XCTAssertTrue(registry.storedValues.isEmpty)
    }

    func testRecordsAndStoredValuesHaveStableOrder() {
        var registry = RuleRegistry()
        let url = URL(fileURLWithPath: "/Applications/App.app")
        _ = registry.setBehavior(.media, for: "z.example", at: url)
        _ = registry.setBehavior(.function, for: "a.example", at: url)

        XCTAssertEqual(registry.records.map(\.id), ["a.example", "z.example"])
        XCTAssertEqual(registry.storedValues.compactMap { $0["id"] as? String }, ["a.example", "z.example"])
    }
}
