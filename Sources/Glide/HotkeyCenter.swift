import AppKit
import Carbon.HIToolbox
import GlideCore

/// Registers global shortcuts with Carbon's `RegisterEventHotKey`. It needs no permission,
/// swallows only the exact combos it owns, and reports combos it can tell are taken. macOS
/// can't detect every clash: an app using an event tap, or one that registers after Glide,
/// goes unnoticed.
final class HotkeyCenter {
    enum Problem: Equatable {
        /// Another app registered the same combo first.
        case inUse
        /// Collides with an enabled macOS shortcut (System Settings › Keyboard › Shortcuts).
        case system
        case failed(OSStatus)

        var message: String {
            switch self {
            case .inUse: "Already in use by another app"
            case .system: "Taken by a macOS shortcut"
            case .failed(let status): "Couldn't register (error \(status))"
            }
        }
    }

    private var hotKeys: [EventHotKeyRef] = []
    private var actionsByID: [UInt32: Action] = [:]
    private var handlerRef: EventHandlerRef?
    private(set) var problems: [Action: Problem] = [:]
    private(set) var isSuspended = false
    var onAction: ((Action) -> Void)?

    private static let signature: OSType = 0x474C_4445 // "GLDE"

    init() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetEventDispatcherTarget(), hotKeyHandler, 1, &spec, refcon, &handlerRef)
    }

    func register(_ keymap: Keymap) {
        unregisterAll()
        isSuspended = false
        problems = [:]
        let systemCombos = Self.enabledSystemShortcuts()
        for (index, binding) in keymap.bindings.enumerated() {
            let id = UInt32(index + 1)
            if systemCombos.contains(binding.combo) {
                problems[binding.action] = .system
                continue
            }
            var ref: EventHotKeyRef?
            let status = RegisterEventHotKey(
                binding.combo.keyCode, binding.combo.modifiers.carbonFlags,
                EventHotKeyID(signature: Self.signature, id: id), GetEventDispatcherTarget(),
                // Exclusive registration fails when another process already holds the combo,
                // instead of succeeding and never firing.
                OptionBits(kEventHotKeyExclusive), &ref
            )
            if status == noErr, let ref {
                hotKeys.append(ref)
                actionsByID[id] = binding.action
            } else {
                problems[binding.action] = status == OSStatus(eventHotKeyExistsErr) ? .inUse : .failed(status)
            }
        }
    }

    /// Releases every shortcut, e.g. while the settings window records a new one.
    func suspend() {
        unregisterAll()
        isSuspended = true
    }

    private func unregisterAll() {
        hotKeys.forEach { UnregisterEventHotKey($0) }
        hotKeys = []
        actionsByID = [:]
    }

    fileprivate func fire(_ id: UInt32) {
        guard let action = actionsByID[id] else { return }
        onAction?(action)
    }

    /// Enabled system-wide shortcuts such as Spotlight or Mission Control.
    private static func enabledSystemShortcuts() -> Set<KeyCombo> {
        var unmanaged: Unmanaged<CFArray>?
        guard CopySymbolicHotKeys(&unmanaged) == noErr, let array = unmanaged?.takeRetainedValue() as? [[String: Any]] else { return [] }
        var result: Set<KeyCombo> = []
        for entry in array {
            guard (entry[kHISymbolicHotKeyEnabled] as? Bool) == true,
                  let code = (entry[kHISymbolicHotKeyCode] as? NSNumber)?.uint32Value,
                  let flags = (entry[kHISymbolicHotKeyModifiers] as? NSNumber)?.uint32Value,
                  // fn/Globe shortcuts (window tiling like 🌐⌃⌥⇧←) need the Globe key held,
                  // so they never fire for the same combo without it.
                  flags & UInt32(kEventKeyModifierFnMask) == 0 else { continue }
            var modifiers: KeyModifiers = []
            if flags & UInt32(controlKey) != 0 { modifiers.insert(.control) }
            if flags & UInt32(optionKey) != 0 { modifiers.insert(.option) }
            if flags & UInt32(shiftKey) != 0 { modifiers.insert(.shift) }
            if flags & UInt32(cmdKey) != 0 { modifiers.insert(.command) }
            result.insert(KeyCombo(code, modifiers))
        }
        return result
    }
}

private func hotKeyHandler(_ next: EventHandlerCallRef?, _ event: EventRef?, _ refcon: UnsafeMutableRawPointer?) -> OSStatus {
    guard let event, let refcon else { return OSStatus(eventNotHandledErr) }
    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
        nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID
    )
    guard status == noErr else { return status }
    let center = Unmanaged<HotkeyCenter>.fromOpaque(refcon).takeUnretainedValue()
    MainActor.assumeIsolated { center.fire(hotKeyID.id) }
    return noErr
}
