import AppKit
import GlideCore
import SwiftUI

/// The tab bars above tabbed columns. Tabs can be windows of different apps, so the bar is
/// Glide's own small window, stacked just above the column's active window. Clicking a tab
/// switches to it without activating Glide.
final class TabBarOverlay {
    struct Tab: Equatable {
        let window: WindowID
        let title: String
        let pid: pid_t?
    }

    struct Bar: Equatable {
        /// In AX coordinates.
        let frame: CGRect
        let tabs: [Tab]
        let activeIndex: Int
        /// The column holds the focused window, so its active tab is highlighted.
        let isFocused: Bool
        var activeWindow: WindowID { tabs[activeIndex].window }
    }

    var onSelect: ((WindowID) -> Void)?
    private var panels: [TabBarPanel] = []

    func show(_ bars: [Bar]) {
        while panels.count < bars.count { panels.append(TabBarPanel()) }
        for (panel, bar) in zip(panels, bars) {
            let wasShown = panel.isVisible
            if panel.bar != bar {
                panel.bar = bar
                panel.hosting.rootView = TabBarView(bar: bar) { [weak self] window in self?.onSelect?(window) }
            }
            panel.setFrame(ScreenGeometry.cocoa(bar.frame), display: true)
            panel.order(.above, relativeTo: Int(bar.activeWindow))
            if !wasShown { panel.fadeIn() }
        }
        for panel in panels.dropFirst(bars.count) { panel.orderOut(nil) }
    }

    func hide() {
        for panel in panels { panel.orderOut(nil) }
    }

    /// Redraws every bar on the next `show`, e.g. after the highlight color changes.
    func invalidate() {
        for panel in panels { panel.bar = nil }
    }
}

private final class TabBarPanel: NSPanel {
    let hosting = FirstMouseHostingView(rootView: TabBarView(bar: nil) { _ in })
    var bar: TabBarOverlay.Bar?

    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        configureAsOverlay()
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = true
        contentView = hosting
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Lets the first click on a tab select it, although Glide's panel is never key.
final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

private struct TabBarView: View {
    let bar: TabBarOverlay.Bar?
    let select: (WindowID) -> Void

    var body: some View {
        if let bar {
            HStack(spacing: 2) {
                ForEach(Array(bar.tabs.enumerated()), id: \.element.window) { index, tab in
                    TabView(tab: tab, isActive: index == bar.activeIndex, isFocused: bar.isFocused)
                        .onTapGesture { select(tab.window) }
                }
            }
            .padding(3)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Opaque: a translucent bar shows desktop widgets through it.
            .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(.separator))
        }
    }
}

private struct TabView: View {
    let tab: TabBarOverlay.Tab
    let isActive: Bool
    let isFocused: Bool

    var body: some View {
        HStack(spacing: 6) {
            if let pid = tab.pid, let icon = NSRunningApplication(processIdentifier: pid)?.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 16, height: 16)
            }
            Text(tab.title)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .font(.system(size: 12, weight: isActive ? .semibold : .regular))
        .foregroundStyle(isActive ? .primary : .secondary)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(highlight, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .contentShape(Rectangle())
        .help(tab.title)
    }

    private var highlight: Color {
        guard isActive else { return .clear }
        guard isFocused else { return .primary.opacity(0.1) }
        return Color(nsColor: Appearance.focusRingColor ?? .controlAccentColor).opacity(0.35)
    }
}
