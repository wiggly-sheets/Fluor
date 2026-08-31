import Foundation

struct RuleRecord: Equatable {
    let id: String
    var url: URL
    var behavior: AppBehavior

    var storedValue: [String: Any] {
        ["id": id, "path": url.path, "behavior": behavior.rawValue]
    }

    init(id: String, url: URL, behavior: AppBehavior) {
        self.id = id
        self.url = url
        self.behavior = behavior
    }

    init?(storedValue: [String: Any]) {
        guard let id = storedValue["id"] as? String,
              let path = storedValue["path"] as? String,
              let rawBehavior = storedValue["behavior"] as? Int,
              let behavior = AppBehavior(rawValue: rawBehavior),
              behavior != .inferred else {
            return nil
        }

        self.init(id: id, url: URL(fileURLWithPath: path), behavior: behavior)
    }
}

struct RuleRegistry {
    private var recordsByID: [String: RuleRecord]

    init(storedValues: [[String: Any]] = []) {
        self.recordsByID = [:]
        for record in storedValues.compactMap(RuleRecord.init(storedValue:)) {
            recordsByID[record.id] = record
        }
    }

    var records: [RuleRecord] {
        recordsByID.values.sorted { $0.id < $1.id }
    }

    var storedValues: [[String: Any]] {
        records.map(\.storedValue)
    }

    func behavior(for id: String) -> AppBehavior {
        recordsByID[id]?.behavior ?? .inferred
    }

    @discardableResult
    mutating func setBehavior(_ behavior: AppBehavior, for id: String, at url: URL) -> Bool {
        if behavior == .inferred {
            return recordsByID.removeValue(forKey: id) != nil
        }

        let replacement = RuleRecord(id: id, url: url, behavior: behavior)
        guard recordsByID[id] != replacement else { return false }
        recordsByID[id] = replacement
        return true
    }
}
