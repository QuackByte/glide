import AppKit
import Sparkle

/// Sparkle, reading the appcast attached to the latest GitHub release (`SUFeedURL` in Info.plist).
/// Updates are EdDSA-signed by the release workflow and checked against `SUPublicEDKey`.
final class Updates {
    private let controller = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: nil, userDriverDelegate: nil)

    var checksAutomatically: Bool {
        get { controller.updater.automaticallyChecksForUpdates }
        set { controller.updater.automaticallyChecksForUpdates = newValue }
    }

    var installsAutomatically: Bool {
        get { controller.updater.automaticallyDownloadsUpdates }
        set { controller.updater.automaticallyDownloadsUpdates = newValue }
    }

    func start() { controller.startUpdater() }

    func checkForUpdates() {
        // A menu bar app isn't frontmost; bring Sparkle's window forward.
        NSApp.activate(ignoringOtherApps: true)
        controller.checkForUpdates(nil)
    }
}
