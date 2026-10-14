import AppKit

/// Shows where a dragged window will land if let go now: an outline over the column it would
/// join, or a bar where it would be inserted on another display. Click-through, above other
/// windows, so the drag itself is never in the way.
final class DropHighlight {
    private lazy var window: NSWindow = {
        let window = NSWindow(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: true)
        window.configureAsOverlay()
        window.ignoresMouseEvents = true
        window.level = .floating
        let view = NSView()
        view.wantsLayer = true
        view.layer?.cornerCurve = .continuous
        window.contentView = view
        return window
    }()
    private var shown: CGRect?

    /// `frame` in AX coordinates. A slim frame (an insertion bar) is filled solid.
    func show(_ frame: CGRect) {
        guard frame != shown else { return }
        let wasShown = shown != nil
        shown = frame
        let color = Appearance.focusRingColor ?? .controlAccentColor
        let isBar = min(frame.width, frame.height) < 12
        let layer = window.contentView?.layer
        layer?.backgroundColor = color.withAlphaComponent(isBar ? 1 : 0.15).cgColor
        layer?.borderColor = color.cgColor
        layer?.borderWidth = isBar ? 0 : 3
        layer?.cornerRadius = isBar ? frame.width / 2 : FocusDecorations.windowCornerRadius
        window.setFrame(ScreenGeometry.cocoa(frame), display: true)
        if !wasShown {
            window.orderFrontRegardless()
            window.fadeIn()
        }
    }

    func hide() {
        guard shown != nil else { return }
        shown = nil
        window.orderOut(nil)
    }
}
