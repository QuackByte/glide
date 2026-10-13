import Foundation
import GlideCore

/// Reads raw finger positions from every trackpad through the private MultitouchSupport
/// framework (the same source BetterTouchTool and similar tools use). Unlike NSEvent gestures,
/// it sees three-finger movement no matter which app is in front.
final class TrackpadMonitor {
    /// Receives touches on the main thread, in normalized trackpad coordinates.
    var onFrame: (([Touch], Double) -> Void)?
    private(set) var isRunning = false
    private var devices: [UnsafeMutableRawPointer] = []
    /// Owns the devices for as long as they report.
    private var deviceList: CFMutableArray?

    private typealias ContactCallback = @convention(c) (Int32, UnsafeMutableRawPointer?, Int32, Double, Int32) -> Int32
    private typealias CreateList = @convention(c) () -> Unmanaged<CFMutableArray>?
    private typealias Register = @convention(c) (UnsafeMutableRawPointer, ContactCallback) -> Void
    private typealias DeviceControl = @convention(c) (UnsafeMutableRawPointer, Int32) -> Int32
    private typealias DeviceStop = @convention(c) (UnsafeMutableRawPointer) -> Int32

    private static let framework = dlopen("/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport", RTLD_NOW)

    private static func symbol<T>(_ name: String, as type: T.Type) -> T? {
        guard let framework, let pointer = dlsym(framework, name) else { return nil }
        return unsafeBitCast(pointer, to: type)
    }

    /// Returns false when the framework or a trackpad is unavailable.
    @discardableResult
    func start() -> Bool {
        guard !isRunning else { return true }
        // A layout mismatch would read garbage; refuse rather than misbehave.
        guard MemoryLayout<MTFinger>.stride == 96 else { return false }
        guard let createList = Self.symbol("MTDeviceCreateList", as: CreateList.self),
              let register = Self.symbol("MTRegisterContactFrameCallback", as: Register.self),
              let startDevice = Self.symbol("MTDeviceStart", as: DeviceControl.self),
              let list = createList()?.takeRetainedValue() else { return false }

        trackpadSink = { [weak self] touches, time in self?.onFrame?(touches, time) }
        for index in 0..<CFArrayGetCount(list) {
            guard let device = UnsafeMutableRawPointer(mutating: CFArrayGetValueAtIndex(list, index)) else { continue }
            register(device, contactFrameCallback)
            _ = startDevice(device, 0)
            devices.append(device)
        }
        deviceList = list
        isRunning = !devices.isEmpty
        return isRunning
    }

    func stop() {
        guard isRunning else { return }
        let unregister = Self.symbol("MTUnregisterContactFrameCallback", as: Register.self)
        let stopDevice = Self.symbol("MTDeviceStop", as: DeviceStop.self)
        for device in devices {
            unregister?(device, contactFrameCallback)
            _ = stopDevice?(device)
        }
        devices = []
        deviceList = nil
        trackpadSink = nil
        isRunning = false
    }
}

/// Mirrors MultitouchSupport's per-finger record (96 bytes).
private struct MTFinger {
    var frame: Int32
    var timestamp: Double
    var identifier: Int32
    var state: Int32
    var fingerID: Int32
    var handID: Int32
    var normalizedX: Float
    var normalizedY: Float
    var normalizedVelocityX: Float
    var normalizedVelocityY: Float
    var size: Float
    var zero1: Int32
    var angle: Float
    var majorAxis: Float
    var minorAxis: Float
    var millimetreX: Float
    var millimetreY: Float
    var millimetreVelocityX: Float
    var millimetreVelocityY: Float
    var zero2: (Int32, Int32)
    var unknown: Float
}

/// Contact states 1…7 run from "hovering" to "lifting"; 3…5 mean the finger is on the pad.
nonisolated private let touchingStates: ClosedRange<Int32> = 3...5

nonisolated(unsafe) private var trackpadSink: (([Touch], Double) -> Void)?

/// Runs on MultitouchSupport's own thread for every frame from every trackpad.
nonisolated private func contactFrameCallback(_ device: Int32, _ data: UnsafeMutableRawPointer?, _ count: Int32, _ timestamp: Double, _ frame: Int32) -> Int32 {
    var touches: [Touch] = []
    if let data, count > 0 {
        let fingers = data.bindMemory(to: MTFinger.self, capacity: Int(count))
        for index in 0..<Int(count) where touchingStates.contains(fingers[index].state) {
            touches.append(Touch(x: Double(fingers[index].normalizedX), y: Double(fingers[index].normalizedY)))
        }
    }
    DispatchQueue.main.async {
        MainActor.assumeIsolated { trackpadSink?(touches, timestamp) }
    }
    return 0
}
