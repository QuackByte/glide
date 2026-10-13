import AppKit
import GlideCore
import ScreenCaptureKit

/// Window previews for the overview. They need Screen Recording access; without it the overview
/// shows app icons instead. ScreenCaptureKit renders a window's own content, so windows parked
/// at the screen edges or hidden in the corner still preview in full.
enum WindowThumbnails {
    static var isAuthorized: Bool { CGPreflightScreenCaptureAccess() }

    /// Shows the system prompt the first time; after that, opens the Screen Recording settings.
    static func requestAccess() {
        if !CGRequestScreenCaptureAccess() {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
        }
    }

    /// Captures each window at most `maxWidth` points wide, delivering images as they arrive.
    static func capture(_ ids: [WindowID], maxWidth: CGFloat, deliver: @escaping @MainActor (WindowID, NSImage) -> Void) async {
        guard isAuthorized, !ids.isEmpty,
              let content = try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false) else { return }
        let wanted = Set(ids)
        let windows = content.windows.filter { wanted.contains($0.windowID) }
        let scale = NSScreen.main?.backingScaleFactor ?? 2
        await withTaskGroup(of: (WindowID, CGImage?).self) { group in
            for window in windows {
                group.addTask {
                    let configuration = SCStreamConfiguration()
                    let factor = min(maxWidth / max(window.frame.width, 1), 1)
                    configuration.width = Int(window.frame.width * factor * scale)
                    configuration.height = Int(window.frame.height * factor * scale)
                    configuration.showsCursor = false
                    configuration.ignoreShadowsSingleWindow = true
                    let filter = SCContentFilter(desktopIndependentWindow: window)
                    let image = try? await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
                    return (window.windowID, image)
                }
            }
            for await (id, image) in group {
                guard let image else { continue }
                let picture = NSImage(cgImage: image, size: NSSize(width: CGFloat(image.width) / scale, height: CGFloat(image.height) / scale))
                await deliver(id, picture)
            }
        }
    }
}
