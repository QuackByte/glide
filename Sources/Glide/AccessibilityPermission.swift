import AppKit
import ApplicationServices

/// Watches Accessibility trust so Glide can start, or stop, without a relaunch.
final class AccessibilityPermission {
    private(set) var isTrusted = AXIsProcessTrusted()
    private var timer: Timer?
    var onChange: ((Bool) -> Void)?

    static let settingsURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!

    /// Adds Glide to the Accessibility list (switched off) and shows the system prompt once.
    func requestPrompt() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        isTrusted = AXIsProcessTrustedWithOptions(options)
    }

    func openSystemSettings() {
        NSWorkspace.shared.open(Self.settingsURL)
    }

    /// Polls quickly while waiting for a grant and slowly afterwards, to notice a revoked grant.
    func startMonitoring() {
        timer?.invalidate()
        let interval: TimeInterval = isTrusted ? 3 : 1
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.poll() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func poll() {
        let trusted = AXIsProcessTrusted()
        guard trusted != isTrusted else { return }
        isTrusted = trusted
        startMonitoring()
        onChange?(trusted)
    }
}
