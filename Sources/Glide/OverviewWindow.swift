import AppKit
import GlideCore
import SwiftUI

/// What the overview shows. Thumbnails arrive asynchronously after it opens.
@Observable
final class OverviewModel {
    var overview: Overview
    var thumbnails: [WindowID: NSImage] = [:]
    let titles: [WindowID: String]
    let pids: [WindowID: pid_t]
    /// App name and title, what typing filters on.
    let searchText: [WindowID: String]
    let activeWorkspace: Int
    let viewportSize: CGSize
    let gap: CGFloat
    let previewsAllowed = WindowThumbnails.isAuthorized

    init(overview: Overview, titles: [WindowID: String], pids: [WindowID: pid_t], activeWorkspace: Int, viewportSize: CGSize, gap: CGFloat) {
        self.overview = overview
        self.titles = titles
        self.pids = pids
        searchText = titles.reduce(into: [:]) { text, entry in
            let app = pids[entry.key].flatMap { NSRunningApplication(processIdentifier: $0)?.localizedName } ?? ""
            text[entry.key] = "\(app) \(entry.value)"
        }
        self.activeWorkspace = activeWorkspace
        self.viewportSize = viewportSize
        self.gap = gap
    }
}

/// A zoomed-out view of every workspace. Arrow keys or the pointer pick a window; Return or a
/// click goes to it, switching workspace if needed. Esc, a click on the background or the
/// overview shortcut closes it.
final class OverviewController {
    private unowned let manager: WindowManager
    private var panel: OverviewPanel?
    private var model: OverviewModel?
    private var captureTask: Task<Void, Never>?

    init(manager: WindowManager) {
        self.manager = manager
    }

    var isShown: Bool { panel != nil }

    func toggle() {
        isShown ? close(goingTo: nil) : show()
    }

    func show() {
        guard !isShown, let overview = manager.makeOverview(), let screen = manager.focusedScreen ?? NSScreen.screens.first else { return NSSound.beep() }
        let ids = overview.rows.flatMap { $0.columns.flatMap(\.windows) }
        var titles: [WindowID: String] = [:]
        var pids: [WindowID: pid_t] = [:]
        for id in ids {
            let summary = manager.windowSummary(id)
            titles[id] = summary.title
            pids[id] = summary.pid
        }
        let model = OverviewModel(overview: overview, titles: titles, pids: pids, activeWorkspace: manager.activeWorkspaceNumber - 1,
                                  viewportSize: manager.viewportSize, gap: Appearance.gap)
        self.model = model

        let panel = OverviewPanel(frame: screen.frame)
        panel.onKey = { [weak self] event in self?.handle(event) ?? false }
        panel.contentView = FirstMouseHostingView(rootView: OverviewView(
            model: model,
            go: { [weak self] window in self?.close(goingTo: window) },
            dismiss: { [weak self] in self?.close(goingTo: nil) }
        ))
        // Dark in both appearances, like Mission Control: tiles stand out against a dim backdrop.
        panel.appearance = NSAppearance(named: .darkAqua)
        self.panel = panel
        panel.makeKeyAndOrderFront(nil)
        panel.fadeIn(duration: 0.12)

        captureTask = Task {
            await WindowThumbnails.capture(ids, maxWidth: 720) { id, image in model.thumbnails[id] = image }
        }
    }

    /// Closes the overview, then focuses `target` if one was chosen.
    func close(goingTo target: WindowID?) {
        captureTask?.cancel()
        captureTask = nil
        guard let panel else { return }
        self.panel = nil
        model = nil
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.1
            panel.animator().alphaValue = 0
        }, completionHandler: {
            panel.orderOut(nil)
        })
        if let target { manager.focusFromOverview(target) }
    }

    private func handle(_ event: NSEvent) -> Bool {
        guard let model else { return false }
        switch Int(event.keyCode) {
        case 123: model.overview.move(.left)
        case 124: model.overview.move(.right)
        case 125: model.overview.move(.down)
        case 126: model.overview.move(.up)
        case 36, 76: if let selection = model.overview.selection { close(goingTo: selection) }
        case 53:
            // Esc clears a filter first, then closes.
            if model.overview.query.isEmpty { close(goingTo: nil) } else { filter("") }
        case 51:
            guard !model.overview.query.isEmpty else { return true }
            filter(String(model.overview.query.dropLast()))
        default:
            guard event.modifierFlags.intersection([.command, .control]).isEmpty,
                  let typed = event.characters, !typed.isEmpty,
                  typed.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) && !(0xF700...0xF8FF).contains($0.value) })
            else { return false }
            filter(model.overview.query + typed)
        }
        return true
    }

    private func filter(_ query: String) {
        guard let model else { return }
        model.overview.filter(query, searchText: model.searchText)
    }
}

/// Takes keyboard focus without activating Glide, so the app you came from stays active if
/// you close the overview without choosing.
private final class OverviewPanel: NSPanel {
    var onKey: ((NSEvent) -> Bool)?

    init(frame: CGRect) {
        super.init(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        configureAsOverlay()
        level = .modalPanel
        hidesOnDeactivate = false
    }

    override var canBecomeKey: Bool { true }

    override func keyDown(with event: NSEvent) {
        if onKey?(event) != true { super.keyDown(with: event) }
    }
}

private struct OverviewView: View {
    let model: OverviewModel
    let go: (WindowID) -> Void
    let dismiss: () -> Void

    private let padding: CGFloat = 72
    private let rowSpacing: CGFloat = 44
    private let footerHeight: CGFloat = 40
    private let searchHeight: CGFloat = 40

    var body: some View {
        GeometryReader { geometry in
            let rows = model.overview.rows
            let count = CGFloat(max(rows.count, 1))
            let available = geometry.size.height - 2 * padding - footerHeight - searchHeight - rowSpacing * (count + 1)
            let rowHeight = max(min(available / count, geometry.size.height * 0.34), 60)
            let scale = rowHeight / max(model.viewportSize.height, 1)

            VStack(alignment: .leading, spacing: rowSpacing) {
                search
                    .frame(maxWidth: .infinity)
                    .frame(height: searchHeight)
                Spacer(minLength: 0)
                ForEach(rows.indices, id: \.self) { index in
                    OverviewRowView(model: model, rowIndex: index, height: rowHeight, scale: scale, go: go)
                }
                Spacer(minLength: 0)
                footer.frame(height: footerHeight)
            }
            .padding(padding)
        }
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(Color.black.opacity(0.45))
                .ignoresSafeArea()
                .onTapGesture(perform: dismiss)
        }
    }

    private var search: some View {
        let overview = model.overview
        return HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            Text(overview.query.isEmpty ? "Type to filter windows" : overview.query)
                .foregroundStyle(overview.query.isEmpty ? .secondary : .primary)
                .lineLimit(1)
            if let matches = overview.matches {
                Text(matches.isEmpty ? "No match" : "\(matches.count) match\(matches.count == 1 ? "" : "es")")
                    .foregroundStyle(.secondary)
                    .padding(.leading, 6)
            }
        }
        .font(.title3)
        .padding(.horizontal, 16)
        .frame(minWidth: 320, maxHeight: .infinity)
        .background(.regularMaterial, in: Capsule())
    }

    private var footer: some View {
        HStack(spacing: 18) {
            hint("abc", "Filter")
            hint("← → ↑ ↓", "Select")
            hint("⏎", "Go")
            hint("esc", "Close")
            Spacer()
            if !model.previewsAllowed {
                Text("Window previews need Screen Recording access.")
                    .foregroundStyle(.white.opacity(0.7))
                Button("Allow…") { WindowThumbnails.requestAccess() }
            }
        }
        .font(.callout)
    }

    private func hint(_ keys: String, _ label: String) -> some View {
        HStack(spacing: 6) {
            Text(keys)
                .fontWeight(.semibold)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 5))
            Text(label)
        }
        .foregroundStyle(.white.opacity(0.85))
    }
}

private enum OverviewMetrics {
    static let columnSpacing: CGFloat = 20
    static let stackSpacing: CGFloat = 14
}

private struct OverviewRowView: View {
    let model: OverviewModel
    let rowIndex: Int
    let height: CGFloat
    let scale: CGFloat
    let go: (WindowID) -> Void

    var body: some View {
        let row = model.overview.rows[rowIndex]
        let isActive = row.workspace == model.activeWorkspace
        HStack(alignment: .center, spacing: 28) {
            Text("\(row.workspace + 1)")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(isActive ? .white : .white.opacity(0.7))
                .frame(width: 40, height: 40)
                .background(isActive ? ringColor : .white.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            if row.columns.isEmpty {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(.white.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                    .frame(width: model.viewportSize.width * scale / 2, height: height)
                    .overlay(Text("Empty").foregroundStyle(.white.opacity(0.6)))
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        // Roomier than the scaled screen gap, which would be a few points.
                        HStack(alignment: .top, spacing: OverviewMetrics.columnSpacing) {
                            ForEach(row.columns.indices, id: \.self) { column in
                                columnView(row: row, column: column)
                                    .frame(width: row.widths[column] * scale, height: height)
                            }
                        }
                        // Room for the selected tile's highlight and shadow.
                        .padding(12)
                    }
                    .onChange(of: model.overview.selection) { _, selection in
                        guard let selection, model.overview.location(of: selection)?.row == rowIndex else { return }
                        withAnimation(.easeOut(duration: 0.15)) { proxy.scrollTo(selection, anchor: .center) }
                    }
                    .onAppear {
                        if let selection = model.overview.selection, model.overview.location(of: selection)?.row == rowIndex {
                            proxy.scrollTo(selection, anchor: .center)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func columnView(row: Overview.Row, column: Int) -> some View {
        let windows = row.columns[column].windows
        if row.columns[column].isTabbed {
            let shown = model.overview.shownWindow(row: rowIndex, column: column)
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    ForEach(windows, id: \.self) { window in
                        AppIcon(pid: model.pids[window], size: 14)
                            .padding(3)
                            .background(window == shown ? .white.opacity(0.3) : .clear, in: RoundedRectangle(cornerRadius: 4))
                            .onTapGesture { go(window) }
                    }
                    Spacer(minLength: 0)
                }
                .frame(height: 20)
                tile(shown)
            }
        } else {
            VStack(spacing: OverviewMetrics.stackSpacing) {
                ForEach(windows, id: \.self) { window in tile(window) }
            }
        }
    }

    private func tile(_ window: WindowID) -> some View {
        OverviewTile(
            image: model.thumbnails[window],
            title: model.titles[window] ?? "",
            pid: model.pids[window],
            isSelected: model.overview.selection == window,
            ringColor: ringColor
        )
        .opacity(model.overview.isMatch(window) ? 1 : 0.22)
        .animation(.easeOut(duration: 0.12), value: model.overview.isMatch(window))
        .id(window)
        .onTapGesture { go(window) }
        .onHover { hovering in
            if hovering { model.overview.select(window) }
        }
    }

    private var ringColor: Color { Color(nsColor: Appearance.focusRingColor ?? .controlAccentColor) }
}

private struct OverviewTile: View {
    let image: NSImage?
    let title: String
    let pid: pid_t?
    let isSelected: Bool
    let ringColor: Color

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
        ZStack {
            shape.fill(.regularMaterial)
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .transition(.opacity)
            } else {
                AppIcon(pid: pid, size: 44)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(shape)
        .overlay(alignment: .bottomLeading) {
            HStack(spacing: 5) {
                AppIcon(pid: pid, size: 14)
                Text(title).lineLimit(1)
            }
            .font(.caption)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(.regularMaterial, in: Capsule())
            .padding(6)
        }
        .overlay(shape.strokeBorder(isSelected ? ringColor : .white.opacity(0.15), lineWidth: isSelected ? 3 : 1))
        .scaleEffect(isSelected ? 1.02 : 1)
        .shadow(color: .black.opacity(isSelected ? 0.4 : 0.2), radius: isSelected ? 10 : 4)
        .animation(.easeOut(duration: 0.12), value: isSelected)
        .animation(.easeOut(duration: 0.2), value: image != nil)
        .contentShape(shape)
    }
}

private struct AppIcon: View {
    let pid: pid_t?
    let size: CGFloat

    var body: some View {
        if let pid, let icon = NSRunningApplication(processIdentifier: pid)?.icon {
            Image(nsImage: icon)
                .resizable()
                .frame(width: size, height: size)
        }
    }
}
