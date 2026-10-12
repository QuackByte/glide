import Foundation

/// The parts of a strip worth keeping across a Glide quit or a tiling off/on cycle: column
/// order, stacks, widths, and which windows the user floated or tiled by hand.
public struct StripSnapshot: Codable, Equatable, Sendable {
    public struct ColumnState: Codable, Equatable, Sendable {
        public var windows: [WindowID]
        public var focusedRow: Int
        public var widthIndex: Int
        public var isFullWidth: Bool
    }

    public var columns: [ColumnState]
    public var focusedWindow: WindowID?
    /// Windows the user floated, and floating-by-default windows the user tiled.
    public var userFloating: [WindowID]
    public var userTiled: [WindowID]
    /// Window IDs are only unique until the Mac restarts, so a snapshot from an earlier boot is ignored.
    public var bootTime: Date

    public init(strip: Strip, userFloating: Set<WindowID>, userTiled: Set<WindowID>, bootTime: Date) {
        columns = strip.columns.map {
            ColumnState(windows: $0.windows, focusedRow: $0.focusedRow, widthIndex: $0.widthIndex, isFullWidth: $0.isFullWidth)
        }
        focusedWindow = strip.focusedWindow
        self.userFloating = userFloating.sorted()
        self.userTiled = userTiled.sorted()
        self.bootTime = bootTime
    }

    /// Rebuilds a strip from the windows that exist now. Saved columns come first, keeping
    /// their order, stacks and widths but dropping windows that have closed. Windows the
    /// snapshot doesn't know follow in the order given.
    public func restore(windows available: [WindowID], widthIndex: Int, presetCount: Int) -> Strip {
        let availableSet = Set(available)
        var placed: Set<WindowID> = []
        var restored: [Column] = []

        for saved in columns {
            let windows = saved.windows.filter { availableSet.contains($0) && !placed.contains($0) }
            guard !windows.isEmpty else { continue }
            placed.formUnion(windows)
            let previouslyFocused = saved.windows[min(max(saved.focusedRow, 0), saved.windows.count - 1)]
            let row = windows.firstIndex(of: previouslyFocused) ?? 0
            let width = (0..<presetCount).contains(saved.widthIndex) ? saved.widthIndex : widthIndex
            restored.append(Column(windows: windows, focusedRow: row, widthIndex: width, isFullWidth: saved.isFullWidth))
        }
        for window in available where !placed.contains(window) {
            restored.append(Column(windows: [window], widthIndex: widthIndex))
            placed.insert(window)
        }

        var strip = Strip(columns: restored)
        if let focusedWindow { strip.focus(focusedWindow) }
        return strip
    }
}
