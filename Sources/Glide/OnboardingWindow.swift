import AppKit
import SwiftUI

final class OnboardingWindowController {
    private unowned let controller: AppController
    private lazy var window: NSWindow = {
        let window = NSWindow(contentViewController: NSHostingController(rootView: OnboardingView(controller: controller)))
        window.title = String(localized: "Welcome to Glide")
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }()

    init(controller: AppController) {
        self.controller = controller
    }

    func show() {
        // A menu bar app isn't frontmost when its menu is used; ask firmly to come forward.
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    func close() {
        window.close()
    }
}

private struct OnboardingView: View {
    let controller: AppController

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 56, height: 56)
                Text("Glide needs Accessibility access")
                    .font(.title2.bold())
            }
            Text("Glide arranges your windows as columns on a strip you scroll with the keyboard. macOS only lets an app move and resize other apps' windows with Accessibility access.")
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 6) {
                Text("1. Click **Open System Settings**.")
                Text("2. Turn on **Glide** under Privacy & Security › Accessibility.")
                Text("3. Come back here. Glide starts on its own, with no relaunch needed.")
            }
            Text("Glide uses this access only to read window positions, move and resize windows, and focus them. It sends nothing over the network.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                ProgressView().controlSize(.small)
                Text("Waiting for permission…").foregroundStyle(.secondary)
                Spacer()
                Button("Quit Glide") { NSApp.terminate(nil) }
                Button("Open System Settings") { controller.permission.openSystemSettings() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 500)
    }
}
