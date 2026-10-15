import AppKit
import GlideCore
import SwiftUI

/// Every action and its shortcut on one page, grouped like the Shortcuts menu. Esc, a click
/// outside or the shortcut again closes it. It never activates Glide, so the app you came from
/// stays active underneath.
final class ShortcutSheetController {
    private var panel: ShortcutSheetPanel?
    private var clickMonitor: Any?

    var isShown: Bool { panel != nil }

    func toggle(keymap: Keymap, problems: [Action: HotkeyCenter.Problem], on screen: NSScreen?) {
        isShown ? close() : show(keymap: keymap, problems: problems, on: screen)
    }

    func show(keymap: Keymap, problems: [Action: HotkeyCenter.Problem], on screen: NSScreen?) {
        guard !isShown, let screen = screen ?? NSScreen.main ?? NSScreen.screens.first else { return }
        let panel = ShortcutSheetPanel()
        panel.onEscape = { [weak self] in self?.close() }
        let host = FirstMouseHostingView(rootView: ShortcutSheetView(keymap: keymap, problems: problems))
        host.setFrameSize(host.fittingSize)
        panel.contentView = host
        panel.setContentSize(host.fittingSize)
        let area = screen.visibleFrame
        panel.setFrameOrigin(CGPoint(x: area.midX - panel.frame.width / 2, y: area.midY - panel.frame.height / 2))
        self.panel = panel
        panel.makeKeyAndOrderFront(nil)
        panel.fadeIn(duration: 0.12)
        // Clicks in other apps don't reach a non-activating panel, so watch for them.
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in self?.close() }
    }

    func close() {
        if let clickMonitor { NSEvent.removeMonitor(clickMonitor) }
        clickMonitor = nil
        guard let panel else { return }
        self.panel = nil
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.1
            panel.animator().alphaValue = 0
        }, completionHandler: {
            panel.orderOut(nil)
        })
    }
}

/// Takes keyboard focus for Esc without activating Glide.
private final class ShortcutSheetPanel: NSPanel {
    var onEscape: (() -> Void)?

    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        configureAsOverlay()
        level = .modalPanel
        hidesOnDeactivate = false
    }

    override var canBecomeKey: Bool { true }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == UInt16(KeyCode.escape) { onEscape?() } else { super.keyDown(with: event) }
    }
}

private struct ShortcutSheetView: View {
    let keymap: Keymap
    let problems: [Action: HotkeyCenter.Problem]

    /// Workspaces are by far the longest group, so they get a column to themselves.
    private let columns: [[Action.Group]] = [[.focus, .move, .column], [.workspaces], [.displays, .general]]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Glide Shortcuts")
                .font(.title2.weight(.semibold))
            HStack(alignment: .top, spacing: 32) {
                ForEach(columns.indices, id: \.self) { index in
                    VStack(alignment: .leading, spacing: 18) {
                        ForEach(columns[index], id: \.self, content: groupView)
                    }
                }
            }
            Text("Press esc to close")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(28)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .fixedSize()
    }

    private func groupView(_ group: Action.Group) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(group.title)
                .font(.headline)
                .padding(.bottom, 2)
            ForEach(Action.allCases.filter { $0.group == group }, id: \.self) { action in
                HStack(spacing: 16) {
                    Text(action.title)
                    Spacer(minLength: 8)
                    shortcut(for: action)
                }
                .help(problems[action]?.message ?? "")
            }
        }
    }

    @ViewBuilder
    private func shortcut(for action: Action) -> some View {
        if problems[action] != nil, let combo = keymap.combo(for: action) {
            Text("⚠︎ \(combo.description)").foregroundStyle(.orange)
        } else if let combo = keymap.combo(for: action) {
            Text(combo.description).foregroundStyle(.secondary)
        } else {
            Text("None").foregroundStyle(.tertiary)
        }
    }
}
