import Foundation

struct UserNotificationEnablement: OptionSet {
    let rawValue: Int

    static let appSwitch: Self = .init(rawValue: 1 << 0)
    static let appKey: Self = .init(rawValue: 1 << 1)
    static let globalKey: Self = .init(rawValue: 1 << 2)

    static let all: Self = [.appSwitch, .appKey, .globalKey]
    static let none: Self = []
}
