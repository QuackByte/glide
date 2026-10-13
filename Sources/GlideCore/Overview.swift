import CoreGraphics
import Foundation

/// A zoomed-out view of every workspace: one row per workspace in use, each showing its columns
/// to scale, and the window the user has selected to jump to.
public struct Overview: Equatable, Sendable {
    public struct Row: Equatable, Sendable {
        public var workspace: Int
        public var columns: [Column]
        /// Each column's width and left edge in strip points, as on screen.
        public var widths: [CGFloat]
        public var offsets: [CGFloat]

        func center(ofColumn index: Int) -> CGFloat { offsets[index] + widths[index] / 2 }
    }

    public enum Direction: Sendable {
        case left, right, up, down
    }

    public private(set) var rows: [Row]
    public private(set) var selection: WindowID?
    /// What the user typed to narrow the overview down.
    public private(set) var query = ""
    /// Windows matching the query, in reading order; nil when there is no query.
    public private(set) var matches: [WindowID]?

    /// Rows for workspaces holding windows, plus the active one even when empty. Selection
    /// starts on the focused window.
    public init(spaces: WorkspaceSet) {
        rows = spaces.workspaces.indices.compactMap { index in
            let workspace = spaces.workspaces[index]
            guard !workspace.strip.isEmpty || index == spaces.activeIndex else { return nil }
            return Row(
                workspace: index,
                columns: workspace.strip.columns,
                widths: workspace.strip.columns.indices.map(workspace.width(ofColumn:)),
                offsets: workspace.columnOffsets()
            )
        }
        selection = spaces.active.strip.focusedWindow ?? rows.lazy.compactMap { $0.columns.first?.focusedWindow }.first
    }

    public func location(of window: WindowID) -> (row: Int, column: Int, index: Int)? {
        for (rowIndex, row) in rows.enumerated() {
            for (columnIndex, column) in row.columns.enumerated() {
                if let index = column.windows.firstIndex(of: window) { return (rowIndex, columnIndex, index) }
            }
        }
        return nil
    }

    /// The window a column shows: the selected one if it is in the column, else its focused window
    /// (for a tabbed column, its active tab).
    public func shownWindow(row: Int, column: Int) -> WindowID {
        let column = rows[row].columns[column]
        if let selection, column.windows.contains(selection) { return selection }
        return column.focusedWindow
    }

    public func isMatch(_ window: WindowID) -> Bool { matches?.contains(window) ?? true }

    /// Keeps the windows whose search text (app name and title) contains every word of the
    /// query, ignoring case and accents, and selects the first match unless the selection still
    /// matches. With no match, nothing is selected.
    public mutating func filter(_ query: String, searchText: [WindowID: String]) {
        self.query = query
        let words = query.split(whereSeparator: \.isWhitespace).map(String.init)
        guard !words.isEmpty else {
            matches = nil
            if selection == nil { selection = rows.lazy.compactMap { $0.columns.first?.focusedWindow }.first }
            return
        }
        let found = rows.flatMap { $0.columns.flatMap(\.windows) }.filter { window in
            let text = searchText[window] ?? ""
            return words.allSatisfy { text.range(of: $0, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
        }
        matches = found
        if let selection, found.contains(selection) { return }
        selection = found.first
    }

    @discardableResult
    public mutating func select(_ window: WindowID) -> Bool {
        guard location(of: window) != nil, isMatch(window) else { return false }
        selection = window
        return true
    }

    /// Left and right step through columns. Up and down step through a stack or tabs first, then
    /// to the next workspace row, landing on the column nearest the current one.
    @discardableResult
    public mutating func move(_ direction: Direction) -> Bool {
        if let matches {
            // While filtering, arrows step through the matches in reading order.
            guard !matches.isEmpty else { return false }
            let current = selection.flatMap { matches.firstIndex(of: $0) }
            let step = direction == .left || direction == .up ? -1 : 1
            let target = current.map { $0 + step } ?? 0
            guard matches.indices.contains(target) else { return false }
            self.selection = matches[target]
            return true
        }
        guard let selection, let (rowIndex, columnIndex, index) = location(of: selection) else { return false }
        let row = rows[rowIndex]
        switch direction {
        case .left, .right:
            let target = columnIndex + (direction == .left ? -1 : 1)
            guard row.columns.indices.contains(target) else { return false }
            self.selection = row.columns[target].focusedWindow
            return true
        case .up, .down:
            let step = direction == .up ? -1 : 1
            let windows = row.columns[columnIndex].windows
            if windows.indices.contains(index + step) {
                self.selection = windows[index + step]
                return true
            }
            let center = row.center(ofColumn: columnIndex)
            var target = rowIndex + step
            while rows.indices.contains(target), rows[target].columns.isEmpty { target += step }
            guard rows.indices.contains(target) else { return false }
            let next = rows[target]
            let nearest = next.columns.indices.min { abs(next.center(ofColumn: $0) - center) < abs(next.center(ofColumn: $1) - center) }!
            self.selection = next.columns[nearest].focusedWindow
            return true
        }
    }
}
