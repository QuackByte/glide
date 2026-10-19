import AppKit
import ApplicationServices
import GlideCore

/// Returns the CGWindowID behind an AX window element. Private but stable for over a decade,
/// and used by every macOS window manager; Glide is distributed outside the App Store.
@_silgen_name("_AXUIElementGetWindow")
nonisolated private func _AXUIElementGetWindow(_ element: AXUIElement, _ id: UnsafeMutablePointer<CGWindowID>) -> AXError

// AXUIElement is a CFType that the AX API lets callers use from any thread.
extension AXUIElement: @retroactive @unchecked Sendable {}

nonisolated extension AXUIElement {
    func value<T>(_ attribute: String) -> T? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(self, attribute as CFString, &value) == .success else { return nil }
        return value as? T
    }

    @discardableResult
    func set(_ attribute: String, _ value: CFTypeRef) -> AXError {
        AXUIElementSetAttributeValue(self, attribute as CFString, value)
    }

    func isSettable(_ attribute: String) -> Bool {
        var settable: DarwinBoolean = false
        return AXUIElementIsAttributeSettable(self, attribute as CFString, &settable) == .success && settable.boolValue
    }

    var pid: pid_t? {
        var pid: pid_t = 0
        return AXUIElementGetPid(self, &pid) == .success ? pid : nil
    }

    var windowID: CGWindowID? {
        var id: CGWindowID = 0
        return _AXUIElementGetWindow(self, &id) == .success && id != 0 ? id : nil
    }

    var role: String? { value(kAXRoleAttribute) }
    var subrole: String? { value(kAXSubroleAttribute) }
    var isMinimized: Bool { value(kAXMinimizedAttribute) ?? false }
    var isFullScreen: Bool { value("AXFullScreen") ?? false }
    var isModal: Bool { value(kAXModalAttribute) ?? false }

    var position: CGPoint? {
        guard let value: AXValue = value(kAXPositionAttribute) else { return nil }
        var point = CGPoint.zero
        return AXValueGetValue(value, .cgPoint, &point) ? point : nil
    }

    var size: CGSize? {
        guard let value: AXValue = value(kAXSizeAttribute) else { return nil }
        var size = CGSize.zero
        return AXValueGetValue(value, .cgSize, &size) ? size : nil
    }

    /// Frame in AX coordinates: top-left origin at the top-left of the primary display.
    var frame: CGRect? {
        guard let position, let size else { return nil }
        return CGRect(origin: position, size: size)
    }

    func setPosition(_ point: CGPoint) {
        var point = point
        if let value = AXValueCreate(.cgPoint, &point) { set(kAXPositionAttribute, value) }
    }

    func setSize(_ size: CGSize) {
        var size = size
        if let value = AXValueCreate(.cgSize, &size) { set(kAXSizeAttribute, value) }
    }

    /// Sets size, then position, then size again: the second resize lands once the window is
    /// somewhere the first one may have been clamped against (the approach Rectangle uses).
    ///
    /// Some apps (Electron ones in particular) take the size but drop the move, so the result
    /// is read back and, if the origin is off, set once more. Returns where the window ended up.
    @discardableResult
    func setFrame(_ frame: CGRect) -> CGRect? {
        setSize(frame.size)
        setPosition(frame.origin)
        if let size, abs(size.width - frame.width) > 1 || abs(size.height - frame.height) > 1 {
            setSize(frame.size)
        }
        guard let actual = self.frame else { return nil }
        if FrameCheck.missedOrigin(target: frame, actual: actual) {
            setPosition(frame.origin)
            return self.frame
        }
        return actual
    }
}

/// How Glide treats a window.
enum WindowKind: Equatable {
    /// A standard, resizable window that joins the strip.
    case tileable
    /// A dialog, panel or fixed-size window: left where the app put it.
    case floating
    /// Not a real window for tiling purposes (popovers, sheets, minimized, full screen).
    case ignored
}

enum WindowClassifier {
    /// Whether a rule may tile this window even though `classify` floats it: a resizable,
    /// movable standard window that isn't modal. Dialogs, sheets and fixed-size windows can't.
    static func canTile(_ element: AXUIElement) -> Bool {
        element.role == kAXWindowRole && element.subrole == kAXStandardWindowSubrole && !element.isModal
            && element.isSettable(kAXSizeAttribute) && element.isSettable(kAXPositionAttribute)
    }

    static func classify(_ element: AXUIElement) -> WindowKind {
        guard element.role == kAXWindowRole else { return .ignored }
        if element.isMinimized || element.isFullScreen { return .ignored }
        switch element.subrole {
        case kAXStandardWindowSubrole:
            break
        case kAXDialogSubrole, kAXSystemDialogSubrole, kAXFloatingWindowSubrole:
            return .floating
        default:
            return .ignored
        }
        if element.isModal { return .floating }
        // Panels such as open/save dialogs claim to be standard windows but lack the title bar
        // buttons of a document window.
        let hasClose: AXUIElement? = element.value(kAXCloseButtonAttribute)
        let hasZoom: AXUIElement? = element.value(kAXZoomButtonAttribute)
        let hasFullScreen: AXUIElement? = element.value(kAXFullScreenButtonAttribute)
        if hasClose == nil || (hasZoom == nil && hasFullScreen == nil) { return .floating }
        guard element.isSettable(kAXSizeAttribute), element.isSettable(kAXPositionAttribute) else { return .floating }
        if let size = element.size, size.width < 120 || size.height < 80 { return .floating }
        return .tileable
    }
}

/// Screen geometry in AX coordinates.
enum ScreenGeometry {
    /// A display Glide tiles: a stable ID, its whole frame, and its visible frame (minus menu
    /// bar and Dock), both in AX coordinates.
    struct Screen: Equatable {
        let id: String
        let frame: CGRect
        let viewport: CGRect
    }

    /// Every display, the main one (with the menu bar) first.
    static func screens() -> [Screen] {
        NSScreen.screens.map { screen in
            Screen(id: id(of: screen), frame: ax(screen.frame), viewport: ax(screen.visibleFrame))
        }
    }

    static func screen(withID id: String) -> NSScreen? {
        NSScreen.screens.first { self.id(of: $0) == id }
    }

    /// The display's UUID, which stays the same across reconnects and restarts.
    private static func id(of screen: NSScreen) -> String {
        guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return screen.localizedName }
        guard let uuid = CGDisplayCreateUUIDFromDisplayID(number.uint32Value)?.takeRetainedValue(),
              let string = CFUUIDCreateString(nil, uuid) as String? else { return "display-\(number)" }
        return string
    }

    /// Converts a rect in Cocoa screen coordinates to AX coordinates (top-left origin).
    private static func ax(_ rect: CGRect) -> CGRect {
        let height = NSScreen.screens.first?.frame.maxY ?? 0
        return CGRect(x: rect.minX, y: height - rect.maxY, width: rect.width, height: rect.height)
    }

    /// Converts a rect in AX coordinates (top-left origin) to Cocoa screen coordinates.
    static func cocoa(_ rect: CGRect) -> CGRect {
        let height = NSScreen.screens.first?.frame.maxY ?? 0
        return CGRect(x: rect.minX, y: height - rect.maxY, width: rect.width, height: rect.height)
    }

    /// Converts a point in Cocoa screen coordinates to AX coordinates.
    static func axPoint(fromCocoa point: CGPoint) -> CGPoint {
        let height = NSScreen.screens.first?.frame.maxY ?? 0
        return CGPoint(x: point.x, y: height - point.y)
    }
}
