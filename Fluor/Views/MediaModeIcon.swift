import Cocoa

enum MediaModeIcon {
    static func image(usesBackground: Bool) -> NSImage {
        let configuration = NSImage.SymbolConfiguration(pointSize: 15, weight: .medium)
        guard let globe = NSImage(
            systemSymbolName: "globe",
            accessibilityDescription: NSLocalizedString("Media keys", comment: "")
        )?.withSymbolConfiguration(configuration) else {
            return NSImage(size: .init(width: 18, height: 18))
        }
        let image = NSImage(size: .init(width: 18, height: 18))
        image.lockFocus()

        if usesBackground {
            NSColor.black.setFill()
            NSBezierPath(
                roundedRect: .init(x: 1, y: 1, width: 16, height: 16),
                xRadius: 3,
                yRadius: 3
            ).fill()
        }

        let globeOrigin = usesBackground
            ? NSPoint(x: 1.83, y: 1.83)
            : NSPoint(x: 1.95, y: 1.7)

        globe.draw(
            in: .init(origin: globeOrigin, size: .init(width: 15, height: 15)),
            from: .zero,
            operation: usesBackground ? .destinationOut : .sourceOver,
            fraction: 1,
            respectFlipped: true,
            hints: nil
        )

        image.unlockFocus()
        image.isTemplate = true
        return image
    }
}
