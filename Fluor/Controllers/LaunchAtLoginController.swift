import Cocoa
import ServiceManagement

@objc(LaunchAtLoginController)
final class LaunchAtLoginController: NSObject {
    private static let statusDidChange = Notification.Name("FluorLaunchAtLoginStatusDidChange")
    private var observers: [NSObjectProtocol] = []

    override init() {
        super.init()

        let center = NotificationCenter.default
        observers = [
            center.addObserver(
                forName: Self.statusDidChange,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.refreshStatus()
            },
            center.addObserver(
                forName: NSApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.refreshStatus()
            }
        ]
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
    }

    override class func automaticallyNotifiesObservers(forKey key: String) -> Bool {
        key == "launchAtLogin" ? false : super.automaticallyNotifiesObservers(forKey: key)
    }

    @objc dynamic var launchAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set { updateLaunchAtLogin(newValue) }
    }

    private func updateLaunchAtLogin(_ enabled: Bool) {
        let service = SMAppService.mainApp

        do {
            if enabled {
                switch service.status {
                case .enabled:
                    break
                case .requiresApproval:
                    SMAppService.openSystemSettingsLoginItems()
                case .notRegistered, .notFound:
                    try service.register()
                    if service.status == .requiresApproval {
                        SMAppService.openSystemSettingsLoginItems()
                    }
                @unknown default:
                    try service.register()
                }
            } else if service.status != .notRegistered && service.status != .notFound {
                try service.unregister()
            }
        } catch {
            NSLog("Unable to %@ launch at login: %@", enabled ? "enable" : "disable", error.localizedDescription)
        }

        NotificationCenter.default.post(name: Self.statusDidChange, object: nil)
    }

    private func refreshStatus() {
        willChangeValue(forKey: "launchAtLogin")
        didChangeValue(forKey: "launchAtLogin")
    }
}
