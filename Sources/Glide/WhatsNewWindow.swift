import AppKit
import GlideCore
import SwiftUI

/// "What's new": entries from CHANGELOG.md, which is built into Glide. Shown once after an update
/// with what changed since the version last seen, and from the menu with every release.
final class WhatsNewWindowController {
    static let changelog: Changelog = {
        guard let url = Bundle.main.url(forResource: "CHANGELOG", withExtension: "md"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return Changelog(markdown: "") }
        return Changelog(markdown: text)
    }()

    private var window: NSWindow?

    func show(_ releases: [Changelog.Release]) {
        guard !releases.isEmpty else { return }
        window?.close()
        let view = WhatsNewView(releases: releases) { [weak self] in self?.window?.close() }
        let window = NSWindow(contentViewController: NSHostingController(rootView: view))
        window.title = "What’s New in Glide"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        self.window = window
        // A menu bar app isn't frontmost; ask firmly to come forward.
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }
}

struct WhatsNewView: View {
    let releases: [Changelog.Release]
    let close: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(releases.enumerated()), id: \.offset) { index, release in
                        ReleaseView(release: release)
                            .padding(.top, index == 0 ? 0 : 28)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(28)
            }
            Divider()
            HStack {
                Spacer()
                Button("Continue", action: close)
                    .keyboardShortcut(.defaultAction)
                    .controlSize(.large)
            }
            .padding(16)
        }
        .frame(width: 520, height: 560)
    }
}

private struct ReleaseView: View {
    let release: Changelog.Release

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Glide \(release.version.description)")
                .font(.title2.weight(.semibold))
            if let date = release.date.flatMap(Self.format) {
                Text(date)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }
            ForEach(Array(release.summary.enumerated()), id: \.offset) { _, paragraph in
                Self.markdown(paragraph)
                    .padding(.top, 10)
            }
            ForEach(Array(release.sections.enumerated()), id: \.offset) { _, section in
                Text(section.title)
                    .font(.headline)
                    .padding(.top, 16)
                ForEach(Array(section.entries.enumerated()), id: \.offset) { _, entry in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("•").foregroundStyle(.tint)
                        Self.markdown(entry)
                    }
                    .padding(.top, 6)
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    /// The changelog's inline markdown: **bold** and [links](https://…).
    private static func markdown(_ text: String) -> Text {
        Text((try? AttributedString(markdown: text)) ?? AttributedString(text))
    }

    private static func format(_ iso: String) -> String? {
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.dateFormat = "yyyy-MM-dd"
        guard let date = parser.date(from: iso) else { return nil }
        return date.formatted(.dateTime.day().month(.wide).year())
    }
}
