import AppKit
import GlideCore

/// One mouse-wheel tick. Notches are positive when the content should move right.
struct WheelTick {
    var horizontal: Bool
    /// The modifiers held during the tick.
    var modifiers: KeyModifiers
    var notches: Double
}

/// Intercepts mouse-wheel ticks with an event tap so the strip can take them. Trackpad scrolling
/// is continuous and passes straight through; only discrete wheel ticks are considered.
final class WheelMonitor {
    /// Returns true to swallow the tick because Glide moved the strip with it. Runs on the main
    /// thread, synchronously inside the tap, so it must be quick.
    var handle: ((WheelTick) -> Bool)?
    private var tap: CFMachPort?

    /// Returns false if the tap can't be created, e.g. without Accessibility access.
    @discardableResult
    func start() -> Bool {
        guard tap == nil else { return true }
        let mask = CGEventMask(1) << CGEventType.scrollWheel.rawValue
        guard let port = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
            eventsOfInterest: mask, callback: wheelTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
        tap = port
        return true
    }

    func stop() {
        guard let tap else { return }
        CGEvent.tapEnable(tap: tap, enable: false)
        CFMachPortInvalidate(tap)
        self.tap = nil
    }

    fileprivate func reenable() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
    }

    fileprivate func process(_ event: CGEvent) -> Bool {
        guard event.getIntegerValueField(.scrollWheelEventIsContinuous) == 0, let handle else { return false }
        let flags = event.flags
        var modifiers: KeyModifiers = []
        if flags.contains(.maskControl) { modifiers.insert(.control) }
        if flags.contains(.maskAlternate) { modifiers.insert(.option) }
        if flags.contains(.maskShift) { modifiers.insert(.shift) }
        if flags.contains(.maskCommand) { modifiers.insert(.command) }
        // Tilt (axis 2) is positive to the right; the vertical wheel (axis 1) is positive when scrolling up.
        let horizontal = event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2) != 0
        let notches: Double
        if horizontal {
            notches = event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2)
        } else {
            notches = -event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1)
        }
        guard notches != 0 else { return false }
        return handle(WheelTick(horizontal: horizontal, modifiers: modifiers, notches: notches))
    }
}

/// C callback for the tap. Returning nil swallows the event.
private func wheelTapCallback(_ proxy: CGEventTapProxy, _ type: CGEventType, _ event: CGEvent, _ refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    guard let refcon else { return Unmanaged.passUnretained(event) }
    let monitor = Unmanaged<WheelMonitor>.fromOpaque(refcon).takeUnretainedValue()
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        MainActor.assumeIsolated { monitor.reenable() }
        return Unmanaged.passUnretained(event)
    }
    let consumed = MainActor.assumeIsolated { monitor.process(event) }
    return consumed ? nil : Unmanaged.passUnretained(event)
}
