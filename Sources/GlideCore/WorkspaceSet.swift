import CoreGraphics

/// Numbered workspaces, each its own strip with its own scroll position. One is active; the
/// windows of the others are hidden. Windows join the active workspace.
public struct WorkspaceSet: Equatable, Sendable {
    public static let count = 9

    public private(set) var workspaces: [Workspace]
    public private(set) var activeIndex = 0

    public init(viewport: CGRect, settings: LayoutSettings = .standard) {
        workspaces = Array(repeating: Workspace(viewport: viewport, settings: settings), count: Self.count)
    }

    public var active: Workspace {
        get { workspaces[activeIndex] }
        set { workspaces[activeIndex] = newValue }
    }

    public var viewport: CGRect {
        get { active.viewport }
        set { for index in workspaces.indices { workspaces[index].viewport = newValue } }
    }

    public var settings: LayoutSettings {
        get { active.settings }
        set { for index in workspaces.indices { workspaces[index].settings = newValue } }
    }

    /// Tiled windows on every workspace, workspace by workspace.
    public var allWindows: [WindowID] { workspaces.flatMap(\.strip.windows) }

    public func index(of window: WindowID) -> Int? {
        workspaces.firstIndex { $0.strip.contains(window) }
    }

    /// Indices of workspaces that hold windows.
    public var occupied: [Int] { workspaces.indices.filter { !workspaces[$0].strip.isEmpty } }

    /// Removes a window from whichever workspace has it, closing up the gap it leaves.
    @discardableResult
    public mutating func remove(_ window: WindowID) -> Int? {
        guard let index = index(of: window) else { return nil }
        workspaces[index].strip.remove(window)
        workspaces[index].minimumWidths[window] = nil
        workspaces[index].settleScroll()
        return index
    }

    public func resolve(_ target: WorkspaceTarget) -> Int? {
        let index = switch target {
        case .index(let index): index
        case .previous: activeIndex - 1
        case .next: activeIndex + 1
        }
        return workspaces.indices.contains(index) ? index : nil
    }

    /// Makes another workspace active. Returns false if it already is, or doesn't exist.
    @discardableResult
    public mutating func activate(_ index: Int) -> Bool {
        guard workspaces.indices.contains(index), index != activeIndex else { return false }
        activeIndex = index
        workspaces[index].settleScroll()
        return true
    }

    /// Sends the active workspace's focused column to another workspace, where it lands right of
    /// that workspace's focused column and takes its focus. The active workspace stays.
    @discardableResult
    public mutating func moveFocusedColumn(to index: Int) -> Bool {
        guard workspaces.indices.contains(index), index != activeIndex,
              let column = workspaces[activeIndex].strip.removeFocusedColumn() else { return false }
        workspaces[activeIndex].settleScroll()
        workspaces[index].strip.insert(column)
        workspaces[index].ensureFocusedVisible()
        return true
    }

    // MARK: Windows that leave and come back

    /// Where a window was, so it can return there after its app is hidden or it is minimized.
    public struct Departure: Equatable, Sendable {
        public var workspace: Int
        /// Another window in the same column, to rejoin.
        public var sibling: WindowID?
        /// The first window of the column to the left; nil if it was the first column.
        public var leftNeighbour: WindowID?
        public var widthIndex: Int
        public var isFullWidth: Bool
    }

    public func departure(of window: WindowID) -> Departure? {
        guard let workspace = index(of: window), let (columnIndex, _) = workspaces[workspace].strip.location(of: window) else { return nil }
        let strip = workspaces[workspace].strip
        let column = strip.columns[columnIndex]
        return Departure(
            workspace: workspace,
            sibling: column.windows.first { $0 != window },
            leftNeighbour: columnIndex > 0 ? strip.columns[columnIndex - 1].windows.first : nil,
            widthIndex: column.widthIndex,
            isFullWidth: column.isFullWidth
        )
    }

    /// Puts a returning window back where it left: into its old column if a sibling is still
    /// there, else as its own column right of its old left neighbour. Returns the workspace.
    @discardableResult
    public mutating func rejoin(_ window: WindowID, from departure: Departure, focus: Bool) -> Int {
        let target = workspaces.indices.contains(departure.workspace) ? departure.workspace : activeIndex
        var strip = workspaces[target].strip
        if let sibling = departure.sibling, strip.join(window, columnOf: sibling, focus: focus) {
            // Rejoined its stack or tabs.
        } else {
            let position: Int? = switch departure.leftNeighbour {
            case nil: 0
            case let neighbour?: strip.location(of: neighbour).map { $0.column + 1 }
            }
            strip.insert(Column(windows: [window], widthIndex: departure.widthIndex, isFullWidth: departure.isFullWidth), at: position, focus: focus)
        }
        workspaces[target].strip = strip
        workspaces[target].ensureFocusedVisible()
        return target
    }

    /// Rebuilds the set from saved strips, e.g. after a relaunch.
    public mutating func restore(strips: [Strip], activeIndex: Int) {
        for index in workspaces.indices {
            workspaces[index].strip = index < strips.count ? strips[index] : Strip()
            workspaces[index].settleScroll()
        }
        self.activeIndex = workspaces.indices.contains(activeIndex) ? activeIndex : 0
    }
}
