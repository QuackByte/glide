import AppKit
import GlideCore

/// Look-and-feel settings. Read each time so changes apply at once.
enum Appearance {
    private static var defaults: UserDefaults { .standard }

    static let gapRange: ClosedRange<CGFloat> = 0...40
    static let dimRange: ClosedRange<Double> = 0.1...0.7

    /// Space between columns, stacked windows and the screen edge.
    static var gap: CGFloat {
        get { (defaults.object(forKey: "gap") as? Double).map { min(max(CGFloat($0), gapRange.lowerBound), gapRange.upperBound) } ?? LayoutSettings.standard.gap }
        set { defaults.set(Double(newValue), forKey: "gap") }
    }

    static var showsFocusRing: Bool {
        get { defaults.object(forKey: "focusRing") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "focusRing") }
    }

    /// nil follows the system accent color.
    static var focusRingColor: NSColor? {
        get {
            guard let parts = defaults.array(forKey: "focusRingColor") as? [Double], parts.count == 4 else { return nil }
            return NSColor(srgbRed: parts[0], green: parts[1], blue: parts[2], alpha: parts[3])
        }
        set {
            guard let color = newValue?.usingColorSpace(.sRGB) else { return defaults.removeObject(forKey: "focusRingColor") }
            let parts = [color.redComponent, color.greenComponent, color.blueComponent, color.alphaComponent]
            defaults.set(parts.map(Double.init), forKey: "focusRingColor")
        }
    }

    static var dimsUnfocusedWindows: Bool {
        get { defaults.object(forKey: "dimUnfocused") as? Bool ?? false }
        set { defaults.set(newValue, forKey: "dimUnfocused") }
    }

    /// Opacity of the dimming sheet.
    static var dimAmount: Double {
        get { (defaults.object(forKey: "dimAmount") as? Double).map { min(max($0, dimRange.lowerBound), dimRange.upperBound) } ?? 0.3 }
        set { defaults.set(newValue, forKey: "dimAmount") }
    }
}

/// Click-through overlay windows that mark the focused window: a ring stacked just above it,
/// and a translucent sheet over the whole screen stacked just below it, which darkens every
/// window behind. Other apps' windows can't be restyled, but overlays can be stacked between them.
///
/// The ring only appears once windows are at rest. Each app redraws a moved window on its own
/// schedule, so an overlay moved alongside drifts hundreds of points off mid-animation.
final class FocusDecorations {
    static let ringWidth: CGFloat = 4
    /// Roughly the corner radius of a standard macOS window.
    static let windowCornerRadius: CGFloat = 16

    /// The window currently decorated.
    private(set) var target: WindowID?
    private lazy var ring = Self.overlay()
    private lazy var dim = Self.overlay()
    private var ringShown = false

    /// Decorates `window` (`frame` in AX coordinates) and restacks the overlays around it.
    func show(around window: WindowID, frame: CGRect) {
        target = window
        if Appearance.showsFocusRing {
            let layer = ring.contentView?.layer
            layer?.borderWidth = Self.ringWidth
            layer?.borderColor = (Appearance.focusRingColor ?? .controlAccentColor).cgColor
            layer?.cornerRadius = Self.windowCornerRadius + Self.ringWidth
            layer?.cornerCurve = .continuous
            ring.setFrame(ScreenGeometry.cocoa(frame).insetBy(dx: -Self.ringWidth, dy: -Self.ringWidth), display: true)
            ring.order(.above, relativeTo: Int(window))
            if !ringShown {
                ringShown = true
                ring.fadeIn()
            }
        } else {
            hideRing()
        }
        if Appearance.dimsUnfocusedWindows, let screen = NSScreen.screens.first {
            dim.setFrame(screen.frame, display: false)
            dim.contentView?.layer?.backgroundColor = NSColor.black.withAlphaComponent(Appearance.dimAmount).cgColor
            dim.order(.below, relativeTo: Int(window))
        } else {
            dim.orderOut(nil)
        }
    }

    /// Hides the ring while windows move; dimming stays, since it doesn't depend on position.
    func hideRing() {
        ringShown = false
        ring.orderOut(nil)
    }

    func hide() {
        target = nil
        hideRing()
        dim.orderOut(nil)
    }

    private static func overlay() -> NSWindow {
        let window = NSWindow(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: true)
        window.configureAsOverlay()
        window.ignoresMouseEvents = true
        let view = NSView()
        view.wantsLayer = true
        window.contentView = view
        return window
    }
}

extension NSWindow {
    /// A borderless, transparent window that stays out of Mission Control, ⌘` and full-screen spaces.
    func configureAsOverlay() {
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isReleasedWhenClosed = false
        animationBehavior = .none
        collectionBehavior = [.transient, .ignoresCycle, .fullScreenNone]
    }

    /// Shows an overlay that was just ordered in with a quick fade.
    func fadeIn(duration: TimeInterval = 0.1) {
        alphaValue = 0
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            animator().alphaValue = 1
        }
    }
}
