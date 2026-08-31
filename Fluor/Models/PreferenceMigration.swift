import Foundation

enum PreferenceMigration {
    static let legacyDomainNames = [
        "com.pyrolyse.FluorTahoe",
        "com.pyrolyse.Fluor"
    ]

    private static let excludedKeys: Set<String> = [
        SettingsKey.userHasAlreadyAnsweredAccessibility
    ]

    static func valuesToMigrate(
        currentDomain: [String: Any],
        legacyDomains: [[String: Any]]
    ) -> [String: Any] {
        var knownValues = currentDomain
        var result: [String: Any] = [:]

        for domain in legacyDomains {
            for (key, value) in domain
            where !key.hasPrefix("NSStatusItem ")
                && !excludedKeys.contains(key)
                && knownValues[key] == nil {
                result[key] = value
                knownValues[key] = value
            }
        }

        return result
    }
}
