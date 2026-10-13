import Foundation

/// The parts of the layout worth keeping across a Glide quit or a tiling off/on cycle: each
/// workspace's column order, stacks, tabs and widths, and which windows the user floated or
/// tiled by hand.
public struct StripSnapshot: Codable, Equatable, Sendable {
    public struct ColumnState: Codable, Equatable, Sendable {
        public var windows: [WindowID]
        public var focusedRow: Int
        public var widthIndex: Int
        public var isFullWidth: Bool
        /// Optional so snapshots saved before tabs existed still load.
        public var isTabbed: Bool?
        public var customWidth: Double?

        init(_ column: Column) {
            windows = column.windows
            focusedRow = column.focusedRow
            widthIndex = column.widthIndex
            isFullWidth = column.isFullWidth
            isTabbed = column.isTabbed
            customWidth = column.customWidth.map(Double.init)
        }
    }

    public struct WorkspaceState: Codable, Equatable, Sendable {
        public var columns: [ColumnState]
        public var focusedWindow: WindowID?

        init(_ strip: Strip) {
            self.init(columns: strip.columns.map(ColumnState.init), focusedWindow: strip.focusedWindow)
        }

        init(columns: [ColumnState], focusedWindow: WindowID?) {
            self.columns = columns
            self.focusedWindow = focusedWindow
        }
    }

    /// The active workspace. Also what snapshots from before workspaces hold.
    public var columns: [ColumnState]
    public var focusedWindow: WindowID?
    /// Every workspace in order; nil in snapshots saved before workspaces existed.
    public var workspaces: [WorkspaceState]?
    public var activeWorkspace: Int?
    /// Windows the user floated, and floating-by-default windows the user tiled.
    public var userFloating: [WindowID]
    public var userTiled: [WindowID]
    /// Window IDs are only unique until the Mac restarts, so a snapshot from an earlier boot is ignored.
    public var bootTime: Date

    public init(strip: Strip, userFloating: Set<WindowID>, userTiled: Set<WindowID>, bootTime: Date) {
        let state = WorkspaceState(strip)
        columns = state.columns
        focusedWindow = state.focusedWindow
        self.userFloating = userFloating.sorted()
        self.userTiled = userTiled.sorted()
        self.bootTime = bootTime
    }

    public init(workspaces set: WorkspaceSet, userFloating: Set<WindowID>, userTiled: Set<WindowID>, bootTime: Date) {
        self.init(strip: set.active.strip, userFloating: userFloating, userTiled: userTiled, bootTime: bootTime)
        workspaces = set.workspaces.map { WorkspaceState($0.strip) }
        activeWorkspace = set.activeIndex
    }

    private var savedWorkspaces: [WorkspaceState] {
        workspaces ?? [WorkspaceState(columns: columns, focusedWindow: focusedWindow)]
    }

    /// Every window in the saved layout, workspace by workspace in strip order.
    public var allWindows: [WindowID] { savedWorkspaces.flatMap { $0.columns.flatMap(\.windows) } }

    /// Rebuilds the active workspace's strip from the windows that exist now. Saved columns come
    /// first, keeping their order, stacks and widths but dropping windows that have closed.
    /// Windows the snapshot doesn't know follow in the order given.
    public func restore(windows available: [WindowID], widthIndex: Int, presetCount: Int) -> Strip {
        let restored = restoreWorkspaces(windows: available, widthIndex: widthIndex, presetCount: presetCount)
        return restored.strips[restored.active]
    }

    /// Rebuilds every workspace. Windows the snapshot doesn't know join the active workspace.
    public func restoreWorkspaces(windows available: [WindowID], widthIndex: Int, presetCount: Int) -> (strips: [Strip], active: Int) {
        let states = savedWorkspaces
        let active = min(max(activeWorkspace ?? 0, 0), max(states.count - 1, 0))
        let availableSet = Set(available)
        var placed: Set<WindowID> = []
        var strips: [Strip] = []

        for state in states {
            var restored: [Column] = []
            for saved in state.columns {
                let windows = saved.windows.filter { availableSet.contains($0) && !placed.contains($0) }
                guard !windows.isEmpty else { continue }
                placed.formUnion(windows)
                let previouslyFocused = saved.windows[min(max(saved.focusedRow, 0), saved.windows.count - 1)]
                let row = windows.firstIndex(of: previouslyFocused) ?? 0
                let width = (0..<presetCount).contains(saved.widthIndex) ? saved.widthIndex : widthIndex
                restored.append(Column(windows: windows, focusedRow: row, widthIndex: width, isFullWidth: saved.isFullWidth, isTabbed: saved.isTabbed ?? false,
                                       customWidth: saved.customWidth.map { CGFloat($0) }))
            }
            var strip = Strip(columns: restored)
            if let focused = state.focusedWindow { strip.focus(focused) }
            strips.append(strip)
        }
        if strips.isEmpty { strips.append(Strip()) }

        var columns = strips[active].columns
        for window in available where !placed.contains(window) {
            columns.append(Column(windows: [window], widthIndex: widthIndex))
            placed.insert(window)
        }
        let focused = strips[active].focusedWindow
        strips[active] = Strip(columns: columns)
        if let focused { strips[active].focus(focused) }
        return (strips, active)
    }
}
