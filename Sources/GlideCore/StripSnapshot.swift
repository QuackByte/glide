import CoreGraphics
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
        /// Optional so snapshots saved before the tiled layout existed still load; nil follows the default.
        public var layout: LayoutMode?

        init(_ workspace: Workspace) {
            self.init(columns: workspace.strip.columns.map(ColumnState.init), focusedWindow: workspace.strip.focusedWindow, layout: workspace.layoutOverride)
        }

        init(columns: [ColumnState], focusedWindow: WindowID?, layout: LayoutMode? = nil) {
            self.columns = columns
            self.focusedWindow = focusedWindow
            self.layout = layout
        }
    }

    /// One display's workspaces, keyed by the display's ID.
    public struct DisplayState: Codable, Equatable, Sendable {
        public var display: String
        public var workspaces: [WorkspaceState]
        public var activeWorkspace: Int
    }

    /// The active workspace. Also what snapshots from before workspaces hold.
    public var columns: [ColumnState]
    public var focusedWindow: WindowID?
    /// Every workspace in order; nil in snapshots saved before workspaces existed.
    public var workspaces: [WorkspaceState]?
    public var activeWorkspace: Int?
    /// Every display's workspaces; nil in snapshots saved before Glide tiled every display, which
    /// were of the main display.
    public var displays: [DisplayState]?
    /// Windows the user floated, and floating-by-default windows the user tiled.
    public var userFloating: [WindowID]
    public var userTiled: [WindowID]
    /// Window IDs are only unique until the Mac restarts, so a snapshot from an earlier boot is ignored.
    public var bootTime: Date

    public init(strip: Strip, userFloating: Set<WindowID>, userTiled: Set<WindowID>, bootTime: Date) {
        columns = strip.columns.map(ColumnState.init)
        focusedWindow = strip.focusedWindow
        self.userFloating = userFloating.sorted()
        self.userTiled = userTiled.sorted()
        self.bootTime = bootTime
    }

    public init(workspaces set: WorkspaceSet, userFloating: Set<WindowID>, userTiled: Set<WindowID>, bootTime: Date) {
        self.init(strip: set.active.strip, userFloating: userFloating, userTiled: userTiled, bootTime: bootTime)
        workspaces = set.workspaces.map(WorkspaceState.init)
        activeWorkspace = set.activeIndex
    }

    /// Every display's workspaces. The first display's also fill the single-display fields, so an
    /// older Glide still finds a layout.
    public init(displays: [(id: String, workspaces: WorkspaceSet)], userFloating: Set<WindowID>, userTiled: Set<WindowID>, bootTime: Date) {
        let main = displays.first?.workspaces ?? WorkspaceSet(viewport: .zero)
        self.init(workspaces: main, userFloating: userFloating, userTiled: userTiled, bootTime: bootTime)
        self.displays = displays.map { display in
            DisplayState(display: display.id, workspaces: display.workspaces.workspaces.map(WorkspaceState.init),
                         activeWorkspace: display.workspaces.activeIndex)
        }
    }

    private var savedWorkspaces: [WorkspaceState] {
        workspaces ?? [WorkspaceState(columns: columns, focusedWindow: focusedWindow)]
    }

    /// Every window in the saved layout, workspace by workspace in strip order.
    public var allWindows: [WindowID] {
        if let displays { return displays.flatMap { $0.workspaces.flatMap { $0.columns.flatMap(\.windows) } } }
        return savedWorkspaces.flatMap { $0.columns.flatMap(\.windows) }
    }

    /// Rebuilds the active workspace's strip from the windows that exist now. Saved columns come
    /// first, keeping their order, stacks and widths but dropping windows that have closed.
    /// Windows the snapshot doesn't know follow in the order given.
    public func restore(windows available: [WindowID], widthIndex: Int, presetCount: Int) -> Strip {
        let restored = restoreWorkspaces(windows: available, widthIndex: widthIndex, presetCount: presetCount)
        return restored.strips[restored.active]
    }

    /// Rebuilds every workspace. Windows the snapshot doesn't know join the active workspace.
    public func restoreWorkspaces(windows available: [WindowID], widthIndex: Int, presetCount: Int) -> (strips: [Strip], active: Int, layouts: [LayoutMode?]) {
        var placed: Set<WindowID> = []
        var restored = Self.rebuild(savedWorkspaces, active: activeWorkspace ?? 0, available: Set(available), placed: &placed,
                                    widthIndex: widthIndex, presetCount: presetCount)
        Self.append(available.filter { !placed.contains($0) }, to: &restored, widthIndex: widthIndex)
        return restored
    }

    /// Rebuilds every display's workspaces, keyed by display ID. `displays` are the IDs of the
    /// displays connected now, the main one first. A saved display that isn't connected hands its
    /// workspaces to the main one. Windows the snapshot doesn't know join the active workspace of
    /// the display they're on.
    public func restoreDisplays(windows available: [(window: WindowID, display: String)], displays connected: [String],
                                widthIndex: Int, presetCount: Int) -> [String: (strips: [Strip], active: Int, layouts: [LayoutMode?])] {
        guard let main = connected.first else { return [:] }
        let saved = self.displays ?? [DisplayState(display: main, workspaces: savedWorkspaces, activeWorkspace: activeWorkspace ?? 0)]
        // Each connected display's saved workspaces, with those of displays now gone added to the main one's.
        var states: [String: (workspaces: [WorkspaceState], active: Int)] = [:]
        for state in saved where connected.contains(state.display) {
            states[state.display] = (state.workspaces, state.activeWorkspace)
        }
        for state in saved where !connected.contains(state.display) {
            var merged = states[main]?.workspaces ?? []
            for (index, workspace) in state.workspaces.enumerated() {
                if index < merged.count {
                    merged[index].columns += workspace.columns
                } else {
                    merged.append(workspace)
                }
            }
            states[main] = (merged, states[main]?.active ?? state.activeWorkspace)
        }

        let availableSet = Set(available.map(\.window))
        var placed: Set<WindowID> = []
        var result: [String: (strips: [Strip], active: Int, layouts: [LayoutMode?])] = [:]
        for display in connected {
            let state = states[display] ?? ([], 0)
            result[display] = Self.rebuild(state.workspaces, active: state.active, available: availableSet, placed: &placed,
                                           widthIndex: widthIndex, presetCount: presetCount)
        }
        for display in connected {
            let newcomers = available.filter { $0.display == display && !placed.contains($0.window) }.map(\.window)
            Self.append(newcomers, to: &result[display, default: ([Strip()], 0, [nil])], widthIndex: widthIndex)
            placed.formUnion(newcomers)
        }
        // Windows on a display that isn't in the list join the main one.
        Self.append(available.map(\.window).filter { !placed.contains($0) }, to: &result[main, default: ([Strip()], 0, [nil])], widthIndex: widthIndex)
        return result
    }

    /// Adds windows the snapshot doesn't know to the end of the active workspace.
    private static func append(_ windows: [WindowID], to restored: inout (strips: [Strip], active: Int, layouts: [LayoutMode?]), widthIndex: Int) {
        guard !windows.isEmpty else { return }
        let strip = restored.strips[restored.active]
        var updated = Strip(columns: strip.columns + windows.map { Column(windows: [$0], widthIndex: widthIndex) })
        if let focused = strip.focusedWindow { updated.focus(focused) }
        restored.strips[restored.active] = updated
    }

    private static func rebuild(_ states: [WorkspaceState], active: Int, available availableSet: Set<WindowID>, placed: inout Set<WindowID>,
                                widthIndex: Int, presetCount: Int) -> (strips: [Strip], active: Int, layouts: [LayoutMode?]) {
        let active = min(max(active, 0), max(states.count - 1, 0))
        var strips: [Strip] = []
        var layouts: [LayoutMode?] = []

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
            layouts.append(state.layout)
        }
        if strips.isEmpty {
            strips.append(Strip())
            layouts.append(nil)
        }
        return (strips, active, layouts)
    }
}
