import CoreGraphics

/// Identifies a window. In the app this is the CoreGraphics window number.
public typealias WindowID = UInt32

public enum HorizontalDirection: Sendable {
    case left, right
}

public enum VerticalDirection: Sendable {
    case up, down
}

/// A column on the strip: one or more windows stacked vertically, sharing one width. A tabbed
/// column shows only its focused window, full height, with the others as tabs.
public struct Column: Equatable, Sendable {
    public internal(set) var windows: [WindowID]
    public internal(set) var focusedRow: Int
    /// Index into `LayoutSettings.widthPresets`.
    public internal(set) var widthIndex: Int
    /// Overrides `widthIndex` with the full viewport width until toggled off.
    public internal(set) var isFullWidth: Bool
    public internal(set) var isTabbed: Bool
    /// A width in points set by resizing a window with the mouse; replaces the preset until the
    /// width is cycled.
    public internal(set) var customWidth: CGFloat?

    public init(windows: [WindowID], focusedRow: Int = 0, widthIndex: Int, isFullWidth: Bool = false, isTabbed: Bool = false, customWidth: CGFloat? = nil) {
        precondition(!windows.isEmpty, "A column needs at least one window")
        self.windows = windows
        self.focusedRow = min(max(focusedRow, 0), windows.count - 1)
        self.widthIndex = widthIndex
        self.isFullWidth = isFullWidth
        self.isTabbed = isTabbed
        self.customWidth = customWidth
    }

    public var focusedWindow: WindowID { windows[focusedRow] }
}

/// The ordered columns of one display and which one has focus. Purely structural: no geometry.
public struct Strip: Equatable, Sendable {
    public private(set) var columns: [Column] = []
    public private(set) var focusedColumnIndex = 0

    public init() {}

    public init(columns: [Column], focusedColumnIndex: Int = 0) {
        self.columns = columns
        self.focusedColumnIndex = columns.isEmpty ? 0 : min(max(focusedColumnIndex, 0), columns.count - 1)
    }

    public var isEmpty: Bool { columns.isEmpty }
    public var focusedColumn: Column? { columns.isEmpty ? nil : columns[focusedColumnIndex] }
    public var focusedWindow: WindowID? { focusedColumn?.focusedWindow }
    public var windows: [WindowID] { columns.flatMap(\.windows) }

    public func contains(_ window: WindowID) -> Bool { location(of: window) != nil }

    public func location(of window: WindowID) -> (column: Int, row: Int)? {
        for (columnIndex, column) in columns.enumerated() {
            if let row = column.windows.firstIndex(of: window) { return (columnIndex, row) }
        }
        return nil
    }

    // MARK: Membership

    /// Adds a window in a new column. By default the column goes right of the focused column.
    public mutating func insert(_ window: WindowID, widthIndex: Int, at index: Int? = nil, focus: Bool = true) {
        guard !contains(window) else { return }
        let target = min(max(index ?? (columns.isEmpty ? 0 : focusedColumnIndex + 1), 0), columns.count)
        columns.insert(Column(windows: [window], widthIndex: widthIndex), at: target)
        if focus || columns.count == 1 {
            focusedColumnIndex = target
        } else if target <= focusedColumnIndex {
            focusedColumnIndex += 1
        }
    }

    /// Adds a whole column (e.g. one moved from another workspace). By default it goes right of
    /// the focused column.
    public mutating func insert(_ column: Column, at index: Int? = nil, focus: Bool = true) {
        let target = min(max(index ?? (columns.isEmpty ? 0 : focusedColumnIndex + 1), 0), columns.count)
        columns.insert(column, at: target)
        if focus || columns.count == 1 {
            focusedColumnIndex = target
        } else if target <= focusedColumnIndex {
            focusedColumnIndex += 1
        }
    }

    /// Adds a window to the bottom of (or as the last tab in) the column holding `sibling`.
    @discardableResult
    public mutating func join(_ window: WindowID, columnOf sibling: WindowID, focus: Bool = true) -> Bool {
        guard !contains(window), let (index, _) = location(of: sibling) else { return false }
        columns[index].windows.append(window)
        if focus {
            columns[index].focusedRow = columns[index].windows.count - 1
            focusedColumnIndex = index
        }
        return true
    }

    /// Takes the focused column out of the strip; focus moves to its left neighbour.
    public mutating func removeFocusedColumn() -> Column? {
        guard !columns.isEmpty else { return nil }
        let column = columns.remove(at: focusedColumnIndex)
        focusedColumnIndex = columns.isEmpty ? 0 : max(min(focusedColumnIndex - 1, columns.count - 1), 0)
        return column
    }

    /// Removes a window. An emptied column disappears and focus moves to its left neighbour.
    @discardableResult
    public mutating func remove(_ window: WindowID) -> Bool {
        guard let (columnIndex, row) = location(of: window) else { return false }
        var column = columns[columnIndex]
        column.windows.remove(at: row)
        if column.windows.isEmpty {
            columns.remove(at: columnIndex)
            if columnIndex < focusedColumnIndex || (columnIndex == focusedColumnIndex && columnIndex > 0) {
                focusedColumnIndex -= 1
            }
            focusedColumnIndex = columns.isEmpty ? 0 : min(focusedColumnIndex, columns.count - 1)
        } else {
            if row < column.focusedRow || column.focusedRow >= column.windows.count {
                column.focusedRow = max(column.focusedRow - 1, 0)
            }
            columns[columnIndex] = column
        }
        return true
    }

    // MARK: Focus

    @discardableResult
    public mutating func focus(_ window: WindowID) -> Bool {
        guard let (columnIndex, row) = location(of: window) else { return false }
        let changed = columnIndex != focusedColumnIndex || columns[columnIndex].focusedRow != row
        focusedColumnIndex = columnIndex
        columns[columnIndex].focusedRow = row
        return changed
    }

    @discardableResult
    public mutating func focusColumn(_ direction: HorizontalDirection) -> Bool {
        let target = focusedColumnIndex + (direction == .left ? -1 : 1)
        guard columns.indices.contains(target) else { return false }
        focusedColumnIndex = target
        return true
    }

    @discardableResult
    public mutating func focusFirstColumn() -> Bool {
        guard !columns.isEmpty, focusedColumnIndex != 0 else { return false }
        focusedColumnIndex = 0
        return true
    }

    @discardableResult
    public mutating func focusLastColumn() -> Bool {
        guard !columns.isEmpty, focusedColumnIndex != columns.count - 1 else { return false }
        focusedColumnIndex = columns.count - 1
        return true
    }

    @discardableResult
    public mutating func focusWindow(_ direction: VerticalDirection) -> Bool {
        guard !columns.isEmpty else { return false }
        let target = columns[focusedColumnIndex].focusedRow + (direction == .up ? -1 : 1)
        guard columns[focusedColumnIndex].windows.indices.contains(target) else { return false }
        columns[focusedColumnIndex].focusedRow = target
        return true
    }

    // MARK: Moving

    @discardableResult
    public mutating func moveColumn(_ direction: HorizontalDirection) -> Bool {
        let target = focusedColumnIndex + (direction == .left ? -1 : 1)
        guard !columns.isEmpty, columns.indices.contains(target) else { return false }
        columns.swapAt(focusedColumnIndex, target)
        focusedColumnIndex = target
        return true
    }

    @discardableResult
    public mutating func moveWindow(_ direction: VerticalDirection) -> Bool {
        guard !columns.isEmpty else { return false }
        var column = columns[focusedColumnIndex]
        let target = column.focusedRow + (direction == .up ? -1 : 1)
        guard column.windows.indices.contains(target) else { return false }
        column.windows.swapAt(column.focusedRow, target)
        column.focusedRow = target
        columns[focusedColumnIndex] = column
        return true
    }

    /// niri's consume-or-expel: a window sharing its column is expelled into a new column on
    /// that side; a window alone in its column joins the bottom of the neighbouring column.
    @discardableResult
    public mutating func consumeOrExpel(_ direction: HorizontalDirection) -> Bool {
        guard !columns.isEmpty else { return false }
        var column = columns[focusedColumnIndex]
        let window = column.focusedWindow

        if column.windows.count > 1 {
            column.windows.remove(at: column.focusedRow)
            column.focusedRow = min(column.focusedRow, column.windows.count - 1)
            columns[focusedColumnIndex] = column
            let target = direction == .left ? focusedColumnIndex : focusedColumnIndex + 1
            columns.insert(Column(windows: [window], widthIndex: column.widthIndex), at: target)
            focusedColumnIndex = target
            return true
        }

        let neighbour = focusedColumnIndex + (direction == .left ? -1 : 1)
        guard columns.indices.contains(neighbour) else { return false }
        columns[neighbour].windows.append(window)
        columns[neighbour].focusedRow = columns[neighbour].windows.count - 1
        columns.remove(at: focusedColumnIndex)
        focusedColumnIndex = direction == .left ? neighbour : neighbour - 1
        return true
    }

    // MARK: Width

    @discardableResult
    public mutating func cycleWidth(presetCount: Int, forward: Bool = true) -> Bool {
        guard !columns.isEmpty, presetCount > 0 else { return false }
        var column = columns[focusedColumnIndex]
        let step = forward ? 1 : presetCount - 1
        column.widthIndex = column.isFullWidth ? column.widthIndex : (column.widthIndex + step) % presetCount
        column.isFullWidth = false
        column.customWidth = nil
        columns[focusedColumnIndex] = column
        return true
    }

    /// Switches the focused column to a preset, dropping any custom or full width.
    @discardableResult
    public mutating func setWidthIndex(_ index: Int) -> Bool {
        guard !columns.isEmpty else { return false }
        columns[focusedColumnIndex].widthIndex = index
        columns[focusedColumnIndex].isFullWidth = false
        columns[focusedColumnIndex].customWidth = nil
        return true
    }

    /// Gives the column holding `window` a width in points, e.g. after the user resized it.
    @discardableResult
    public mutating func setCustomWidth(_ width: CGFloat, forColumnOf window: WindowID) -> Bool {
        guard let (index, _) = location(of: window) else { return false }
        columns[index].customWidth = width
        columns[index].isFullWidth = false
        return true
    }

    @discardableResult
    public mutating func toggleFullWidth() -> Bool {
        guard !columns.isEmpty else { return false }
        columns[focusedColumnIndex].isFullWidth.toggle()
        return true
    }

    // MARK: Tabs

    /// Switches the focused column between stacked windows and tabs.
    @discardableResult
    public mutating func toggleTabbed() -> Bool {
        guard !columns.isEmpty else { return false }
        columns[focusedColumnIndex].isTabbed.toggle()
        return true
    }
}
