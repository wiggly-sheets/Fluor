import Foundation

enum KeyboardModePolicy {
    static func desiredMode(
        isDisabled: Bool,
        launchMode: FKeyMode,
        switchMethod: SwitchMethod,
        appBehavior: AppBehavior,
        defaultMode: FKeyMode
    ) -> FKeyMode {
        if isDisabled {
            return launchMode
        }

        switch switchMethod {
        case .key:
            return defaultMode
        case .window, .hybrid:
            switch appBehavior {
            case .inferred:
                return defaultMode
            case .media:
                return .media
            case .function:
                return .function
            }
        }
    }
}
