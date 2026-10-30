import CoreGraphics

/// What a window is, beyond its ID: its app and its title. Window IDs start over when the Mac
/// restarts, so this is how a saved layout finds its windows again.
public struct WindowIdentity: Codable, Equatable, Sendable {
    public var window: WindowID
    public var bundleID: String
    public var title: String

    public init(window: WindowID, bundleID: String, title: String) {
        self.window = window
        self.bundleID = bundleID
        self.title = title
    }
}

/// Puts windows back where they were before the Mac restarted, as they open again. Each window
/// that opens is matched to a saved one of the same app, by title first, then in the saved order,
/// and goes back next to whichever of its old neighbours are already back.
public struct RestartPlan: Sendable {
    struct Entry: Sendable {
        var identity: WindowIdentity
        var display: String
        var workspace: Int
        /// Saved IDs of the other windows in its column.
        var columnMates: [WindowID]
        /// Saved IDs of the windows in the columns to its left, the nearest column first.
        var leftWindows: [WindowID]
        var widthIndex: Int
        var isFullWidth: Bool
        var customWidth: CGFloat?
    }

    private var entries: [Entry]
    /// Saved IDs to the IDs the windows have now.
    private var found: [WindowID: WindowID] = [:]
    /// Each display's workspace layouts and tiled column counts, to set before windows return.
    public let layouts: [String: (layouts: [LayoutMode?], tiledColumns: [Int?])]

    /// nil if the snapshot has no identities, or no windows.
    public init?(snapshot: StripSnapshot, mainDisplay: String) {
        guard let identities = snapshot.identities else { return nil }
        let byWindow = Dictionary(identities.map { ($0.window, $0) }, uniquingKeysWith: { first, _ in first })
        let displays = snapshot.displays ?? [StripSnapshot.DisplayState(
            display: mainDisplay, workspaces: snapshot.workspaces ?? [.init(columns: snapshot.columns, focusedWindow: snapshot.focusedWindow)],
            activeWorkspace: snapshot.activeWorkspace ?? 0)]
        var entries: [Entry] = []
        var layouts: [String: (layouts: [LayoutMode?], tiledColumns: [Int?])] = [:]
        for display in displays {
            layouts[display.display] = (display.workspaces.map(\.layout), display.workspaces.map(\.tiledColumns))
            for (workspace, state) in display.workspaces.enumerated() {
                for (index, column) in state.columns.enumerated() {
                    let left = state.columns[..<index].reversed().flatMap(\.windows)
                    for window in column.windows {
                        guard let identity = byWindow[window] else { continue }
                        entries.append(Entry(identity: identity, display: display.display, workspace: workspace,
                                             columnMates: column.windows.filter { $0 != window }, leftWindows: left,
                                             widthIndex: column.widthIndex, isFullWidth: column.isFullWidth,
                                             customWidth: column.customWidth.map { CGFloat($0) }))
                    }
                }
            }
        }
        guard !entries.isEmpty else { return nil }
        self.entries = entries
        self.layouts = layouts
    }

    public var isEmpty: Bool { entries.isEmpty }

    /// Where a window that just opened goes, if it is one the plan is waiting for: the display's
    /// ID and its place there. Each saved window is handed out once.
    public mutating func claim(_ window: WindowID, bundleID: String, title: String) -> (display: String, departure: WorkspaceSet.Departure)? {
        let sameApp = entries.indices.filter { entries[$0].identity.bundleID == bundleID }
        guard let index = sameApp.first(where: { entries[$0].identity.title == title }) ?? sameApp.first else { return nil }
        let entry = entries.remove(at: index)
        found[entry.identity.window] = window
        let found = found
        let departure = WorkspaceSet.Departure(
            workspace: entry.workspace,
            sibling: entry.columnMates.first { found[$0] != nil }.flatMap { found[$0] },
            leftNeighbour: entry.leftWindows.first { found[$0] != nil }.flatMap { found[$0] },
            widthIndex: entry.widthIndex, isFullWidth: entry.isFullWidth, customWidth: entry.customWidth)
        return (entry.display, departure)
    }
}
