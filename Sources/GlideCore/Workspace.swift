import CoreGraphics

/// How a workspace arranges its columns. Raw values are persisted; do not rename them.
public enum LayoutMode: String, CaseIterable, Codable, Sendable {
    /// Columns keep their preset widths on a strip that scrolls.
    case scrolling
    /// Every window fits on screen, tiled in a spiral: columns first, then the last column splits again and again.
    case tiled
}

public struct LayoutSettings: Equatable, Sendable {
    /// Space between columns, between stacked windows, and around the viewport edge.
    public var gap: CGFloat
    /// How much of an off-screen column stays visible at the screen edge.
    public var sliver: CGFloat
    /// Fractions of the viewport a column can take, cycled in order.
    public var widthPresets: [CGFloat]
    public var defaultWidthIndex: Int
    /// Height of a tabbed column's tab bar; the window sits `tabBarSpacing` below it.
    public var tabBarHeight: CGFloat
    public var tabBarSpacing: CGFloat
    /// The layout of every workspace the user hasn't switched by hand.
    public var defaultLayout: LayoutMode
    /// How many columns tiled workspaces without their own count use, 2 or 3; nil picks by the screen's shape.
    public var defaultTiledColumns: Int?

    public init(gap: CGFloat = 12, sliver: CGFloat = 4, widthPresets: [CGFloat] = [1.0 / 3, 0.5, 2.0 / 3, 1], defaultWidthIndex: Int = 1,
                tabBarHeight: CGFloat = 28, tabBarSpacing: CGFloat = 4, defaultLayout: LayoutMode = .scrolling,
                defaultTiledColumns: Int? = nil) {
        precondition(!widthPresets.isEmpty, "At least one width preset is required")
        self.gap = gap
        self.sliver = sliver
        self.widthPresets = widthPresets
        self.defaultWidthIndex = min(max(defaultWidthIndex, 0), widthPresets.count - 1)
        self.tabBarHeight = tabBarHeight
        self.tabBarSpacing = tabBarSpacing
        self.defaultLayout = defaultLayout
        self.defaultTiledColumns = defaultTiledColumns.map(TiledLayout.clampColumns)
    }

    public static let standard = LayoutSettings()
}

/// Where a column sits relative to the viewport.
public enum Visibility: Equatable, Sendable {
    case visible
    /// Partly on screen at its real position.
    case partial
    /// Entirely off screen: parked as a sliver at the left or right screen edge.
    case parkedLeft
    case parkedRight
    /// A tab that isn't showing. macOS won't put a window wholly off screen, so it waits in the
    /// bottom-right corner with a point or so showing.
    case hiddenTab
}

public enum HiddenCorner: Equatable, Sendable {
    case bottomRight
    case bottomLeft
}

public struct WindowPlacement: Equatable, Sendable {
    public var window: WindowID
    public var frame: CGRect
    public var visibility: Visibility
}

/// The tab bar above a tabbed column that is at least partly on screen.
public struct TabBarPlacement: Equatable, Sendable {
    public var column: Int
    public var frame: CGRect
    public var windows: [WindowID]
    public var activeIndex: Int
    public var activeWindow: WindowID { windows[activeIndex] }
}

/// A strip plus the geometry needed to lay it out: the viewport, the scroll position, and
/// minimum sizes learned from apps. Coordinates use a top-left origin, like the AX API.
public struct Workspace: Equatable, Sendable {
    public var strip: Strip
    public var viewport: CGRect
    public var settings: LayoutSettings
    /// Strip coordinate shown at the left edge of the usable area.
    public private(set) var scrollOffset: CGFloat = 0
    /// Widths that apps refused to shrink below, keyed by window.
    public var minimumWidths: [WindowID: CGFloat] = [:]
    /// Which bottom corner hidden windows wait in: the one with no other display beyond it.
    public var hiddenCorner: HiddenCorner = .bottomRight
    /// This workspace's own layout, once the user has switched it; nil follows `LayoutSettings.defaultLayout`.
    public var layoutOverride: LayoutMode?
    /// This workspace's own tiled column count (2 or 3), once the user has switched it; nil follows the default.
    public var tiledColumnsOverride: Int?
    /// What the first part of each split gets, by split (see `TiledLayout`); 0 keeps a split's default.
    /// Only used while it has one entry per split, so it starts over when windows come or go.
    public var tiledRatios: [CGFloat]?
    /// The window whose tile fills the screen (tiled "full width"); only counts while that tile has focus.
    public private(set) var zoomedWindow: WindowID?

    public init(strip: Strip = Strip(), viewport: CGRect, settings: LayoutSettings = .standard) {
        self.strip = strip
        self.viewport = viewport
        self.settings = settings
    }

    public var layout: LayoutMode { layoutOverride ?? settings.defaultLayout }

    /// How many columns this workspace tiles into: its own count, else the default, else 3 on an ultrawide screen and 2 elsewhere.
    public var tiledColumns: Int {
        TiledLayout.clampColumns(tiledColumnsOverride ?? settings.defaultTiledColumns ?? TiledLayout.autoColumns(for: viewport))
    }

    /// Switches between scrolling and tiled, for this workspace only. Going tiled gives every
    /// window of a stack its own column; going back to scrolling gives every column the default width.
    public mutating func toggleLayout() {
        layoutOverride = layout == .scrolling ? .tiled : .scrolling
        if layout == .scrolling {
            strip.resetWidths(to: settings.defaultWidthIndex)
            zoomedWindow = nil
        }
        settleScroll()
    }

    /// Switches this workspace between 2 and 3 tiled columns, starting its splits over.
    public mutating func cycleTiledColumns() {
        tiledColumnsOverride = tiledColumns == TiledLayout.minColumns ? TiledLayout.maxColumns : TiledLayout.minColumns
        tiledRatios = nil
    }

    // MARK: Geometry

    public var usableWidth: CGFloat { max(viewport.width - 2 * settings.gap, 0) }

    /// Where a hidden window of `size` waits: hidden tabs, and every window of an inactive
    /// workspace. macOS keeps part of a window on screen, so this leaves about a point showing.
    public func hiddenFrame(size: CGSize) -> CGRect {
        let x = hiddenCorner == .bottomRight ? viewport.maxX - 1 : viewport.minX - size.width + 1
        return CGRect(origin: CGPoint(x: x, y: viewport.maxY - 1), size: size)
    }

    /// A column's width on the strip: its preset or custom width, at least as wide as its windows allow.
    public func width(ofColumn index: Int) -> CGFloat {
        let column = strip.columns[index]
        let presets = settings.widthPresets
        let preset = column.isFullWidth ? presetWidth(1)
            : column.customWidth?.rounded() ?? presetWidth(presets[min(max(column.widthIndex, 0), presets.count - 1)])
        return min(max(preset, minimumWidth(of: column)), usableWidth)
    }

    private func minimumWidth(of column: Column) -> CGFloat {
        column.windows.compactMap { minimumWidths[$0] }.max() ?? 0
    }

    /// Every column's width on the strip, worked out once.
    private func widths() -> [CGFloat] { strip.columns.indices.map(width(ofColumn:)) }

    /// Preset fractions are of the whole viewport, so two ½ columns exactly fill it, gaps included.
    public func presetWidth(_ fraction: CGFloat) -> CGFloat {
        ((viewport.width - settings.gap) * fraction - settings.gap).rounded()
    }

    /// The strip coordinate of each column's left edge.
    public func columnOffsets() -> [CGFloat] { offsets(for: widths()) }

    private func offsets(for widths: [CGFloat]) -> [CGFloat] {
        var offsets: [CGFloat] = []
        var x: CGFloat = 0
        for width in widths {
            offsets.append(x)
            x += width + settings.gap
        }
        return offsets
    }

    public var contentWidth: CGFloat {
        let widths = widths()
        guard let last = widths.last else { return 0 }
        return offsets(for: widths)[widths.count - 1] + last
    }

    // MARK: Scrolling

    /// Tiled workspaces don't scroll: everything is on screen. They keep one tile per column
    /// instead (a window dropped onto another's column becomes the next tile) and forget a zoom
    /// whose window has gone.
    private mutating func keepTiledShape() {
        strip.explodeStacks()
        scrollOffset = 0
        if let zoomed = zoomedWindow, !strip.contains(zoomed) { zoomedWindow = nil }
    }

    /// Scrolls as little as possible to bring the focused column fully on screen.
    public mutating func ensureFocusedVisible() {
        if layout == .tiled {
            keepTiledShape()
            return
        }
        guard !strip.isEmpty else {
            scrollOffset = 0
            return
        }
        let index = strip.focusedColumnIndex
        let widths = widths()
        let left = offsets(for: widths)[index]
        let right = left + widths[index]
        if left < scrollOffset {
            scrollOffset = left
        } else if right > scrollOffset + usableWidth {
            scrollOffset = right - usableWidth
        }
    }

    public mutating func centerFocusedColumn() {
        guard !strip.isEmpty, layout == .scrolling else { return }
        let index = strip.focusedColumnIndex
        let widths = widths()
        scrollOffset = (offsets(for: widths)[index] + widths[index] / 2 - usableWidth / 2).rounded()
    }

    /// Removes empty space past either end of the strip, then keeps focus visible.
    /// Use after windows leave or the viewport changes.
    public mutating func settleScroll() {
        if layout == .tiled {
            keepTiledShape()
            return
        }
        let maximum = max(contentWidth - usableWidth, 0)
        scrollOffset = min(max(scrollOffset, 0), maximum)
        ensureFocusedVisible()
    }

    // MARK: Gesture scrolling

    /// The scroll range that shows no empty space past the strip's ends.
    public var scrollBounds: ClosedRange<CGFloat> { 0...(layout == .tiled ? 0 : max(contentWidth - usableWidth, 0)) }

    /// Moves the strip with the fingers. Past either end it follows at a third of the speed,
    /// up to a quarter of the screen, like a rubber band.
    public mutating func scroll(by delta: CGFloat) {
        guard layout == .scrolling else { return }
        let bounds = scrollBounds
        let limit = usableWidth / 4
        let outside = scrollOffset < bounds.lowerBound || scrollOffset > bounds.upperBound
            || scrollOffset + delta < bounds.lowerBound || scrollOffset + delta > bounds.upperBound
        let next = scrollOffset + (outside ? delta / 3 : delta)
        scrollOffset = min(max(next, bounds.lowerBound - limit), bounds.upperBound + limit)
    }

    /// The column-aligned scroll position nearest to `offset`: some column's left edge at the
    /// left of the screen, or its right edge at the right, never past the strip's ends.
    public func snappedOffset(near offset: CGFloat) -> CGFloat {
        let bounds = scrollBounds
        let widths = widths()
        let offsets = offsets(for: widths)
        var candidates: [CGFloat] = [bounds.lowerBound, bounds.upperBound]
        for index in widths.indices {
            candidates.append(offsets[index])
            candidates.append(offsets[index] + widths[index] - usableWidth)
        }
        let clamped = candidates.map { min(max($0, bounds.lowerBound), bounds.upperBound) }
        return clamped.min { abs($0 - offset) < abs($1 - offset) } ?? 0
    }

    /// Ends a swipe: snaps near where momentum would carry the strip, then keeps focus on a
    /// column that is fully on screen there (preferring the current one, else the one nearest
    /// the middle). Returns true if focus moved.
    @discardableResult
    public mutating func settleSwipe(projectedOffset: CGFloat) -> Bool {
        guard !strip.isEmpty, layout == .scrolling else {
            scrollOffset = 0
            return false
        }
        scrollOffset = snappedOffset(near: projectedOffset)
        let widths = widths()
        let offsets = offsets(for: widths)
        func fullyVisible(_ index: Int) -> Bool {
            offsets[index] >= scrollOffset - 0.5 && offsets[index] + widths[index] <= scrollOffset + usableWidth + 0.5
        }
        let current = strip.focusedColumnIndex
        guard !fullyVisible(current) else { return false }
        let middle = scrollOffset + usableWidth / 2
        let candidates = strip.columns.indices.filter(fullyVisible)
        let nearest = (candidates.isEmpty ? Array(strip.columns.indices) : candidates).min {
            abs(offsets[$0] + widths[$0] / 2 - middle) < abs(offsets[$1] + widths[$1] / 2 - middle)
        }!
        strip.focus(strip.columns[nearest].focusedWindow)
        ensureFocusedVisible()
        return true
    }

    // MARK: Actions

    /// Applies a layout action. Returns false if it changed nothing or is not a layout action.
    @discardableResult
    public mutating func perform(_ action: Action) -> Bool {
        if action == .cycleTiledColumns {
            cycleTiledColumns()
            return true
        }
        if layout == .tiled, let tiledChanged = performTiled(action) { return tiledChanged }
        let changed: Bool
        switch action {
        case .focusColumnLeft: changed = strip.focusColumn(.left)
        case .focusColumnRight: changed = strip.focusColumn(.right)
        case .focusFirstColumn: changed = strip.focusFirstColumn()
        case .focusLastColumn: changed = strip.focusLastColumn()
        case .focusWindowUp: changed = strip.focusWindow(.up)
        case .focusWindowDown: changed = strip.focusWindow(.down)
        case .moveColumnLeft: changed = strip.moveColumn(.left)
        case .moveColumnRight: changed = strip.moveColumn(.right)
        case .moveWindowUp: changed = strip.moveWindow(.up)
        case .moveWindowDown: changed = strip.moveWindow(.down)
        case .consumeOrExpelLeft: changed = strip.consumeOrExpel(.left)
        case .consumeOrExpelRight: changed = strip.consumeOrExpel(.right)
        case .cycleColumnWidth: changed = cycleWidth(forward: true)
        case .cycleColumnWidthBackward: changed = cycleWidth(forward: false)
        case .toggleFullWidth: changed = strip.toggleFullWidth()
        case .toggleTabbed: changed = strip.toggleTabbed()
        case .centerColumn:
            let before = scrollOffset
            centerFocusedColumn()
            return scrollOffset != before
        case .toggleLayout:
            toggleLayout()
            return true
        case .toggleOverview, .showShortcuts, .toggleFloating, .toggleTiling:
            return false
        default:
            // Workspace actions act on the whole `WorkspaceSet`.
            return false
        }
        if changed {
            // Tiled keeps one tile per column, so a tab toggle can add or remove tiles; a stack's expelled window may close a gap.
            if action == .consumeOrExpelLeft || action == .consumeOrExpelRight || layout == .tiled {
                settleScroll()
            } else {
                ensureFocusedVisible()
            }
        }
        return changed
    }

    /// From a custom width, cycling moves to the next preset in that direction (wrapping);
    /// otherwise it steps through the presets.
    private mutating func cycleWidth(forward: Bool) -> Bool {
        guard let column = strip.focusedColumn else { return false }
        guard let custom = column.customWidth, !column.isFullWidth else {
            return strip.cycleWidth(presetCount: settings.widthPresets.count, forward: forward)
        }
        let widths = settings.widthPresets.map(presetWidth)
        let index = forward
            ? widths.firstIndex { $0 > custom + 1 } ?? 0
            : widths.lastIndex { $0 < custom - 1 } ?? widths.count - 1
        return strip.setWidthIndex(index)
    }

    /// Adopts the width the user just dragged `window` to. On the strip that is its column's width.
    /// Tiled, it moves the nearest column split that decides the tile's width, so the layout stays
    /// a spiral; a tile whose width no split decides (it is alone) snaps back. Returns false if
    /// nothing changed.
    @discardableResult
    public mutating func setColumnWidthFromResize(_ window: WindowID, to width: CGFloat) -> Bool {
        guard layout == .tiled else { return strip.setCustomWidth(width, forColumnOf: window) }
        let tiles = tiles()
        guard let index = tiles.firstIndex(where: { tileWindows($0).contains(window) }), zoomedWindow == nil else { return false }
        let count = tiles.count
        let splits = TiledLayout.splits(in: viewport, count: count, columns: tiledColumns, gap: settings.gap, ratios: effectiveRatios(count))
        // The split that sizes the tile across: its own if that one is side by side (the tile is its first part), else the nearest earlier one (it is in the second part).
        let split: Int
        let isFirstPart: Bool
        if index < count - 1, splits[index].sideBySide {
            (split, isFirstPart) = (index, true)
        } else if let earlier = (0..<min(index, count - 1)).reversed().first(where: { splits[$0].sideBySide }) {
            (split, isFirstPart) = (earlier, false)
        } else {
            return false
        }
        let available = splits[split].room.width - settings.gap
        guard available > 0 else { return false }
        let share = min(max(width / available, 0.1), 0.9)
        return setTiledRatio(split: split, count: count, to: isFirstPart ? share : 1 - share)
    }

    // MARK: Tiled

    /// A tile: a column's one window, or a whole tabbed column (`row` is then nil).
    private struct Tile {
        var column: Int
        var row: Int?
    }

    /// The tiles in order: columns left to right, a stack's windows top to bottom.
    private func tiles() -> [Tile] {
        strip.columns.enumerated().flatMap { index, column -> [Tile] in
            column.isTabbed ? [Tile(column: index, row: nil)] : column.windows.indices.map { Tile(column: index, row: $0) }
        }
    }

    private func tileWindows(_ tile: Tile) -> [WindowID] {
        let windows = strip.columns[tile.column].windows
        return tile.row.map { [windows[$0]] } ?? windows
    }

    /// The splits' ratios, if they were set for this many tiles.
    private func effectiveRatios(_ count: Int) -> [CGFloat]? {
        guard let ratios = tiledRatios, ratios.count == count - 1 else { return nil }
        return ratios
    }

    /// The tile holding the zoomed window, while it has focus.
    private func zoomedTile(in tiles: [Tile]) -> Int? {
        guard let zoomed = zoomedWindow, let focused = strip.focusedColumn, focused.windows.contains(zoomed) else { return nil }
        return tiles.firstIndex { $0.column == strip.focusedColumnIndex && ($0.row == nil || focused.windows[$0.row!] == zoomed) }
    }

    /// Every tile's frame as the spiral lays it out, before minimum widths and zoom: what focus
    /// and move go by, and what the ratios shape.
    private func tileFrames(_ tiles: [Tile]) -> [CGRect] {
        TiledLayout.frames(in: viewport, count: tiles.count, columns: tiledColumns, gap: settings.gap, ratios: effectiveRatios(tiles.count))
    }

    /// The frames tiles are sent to: a tile narrower than a window in it allows gets that window's
    /// minimum width within its own x, overlapping its neighbour if it must; a zoomed tile fills the screen.
    private func placedFrames(_ tiles: [Tile]) -> [CGRect] {
        var frames = tileFrames(tiles)
        let gap = settings.gap
        let right = viewport.maxX - gap
        for index in frames.indices {
            let minimum = tileWindows(tiles[index]).compactMap { minimumWidths[$0] }.max() ?? 0
            guard frames[index].width < minimum else { continue }
            let width = min(minimum, usableWidth)
            frames[index].origin.x = min(frames[index].minX, max(right - width, viewport.minX + gap))
            frames[index].size.width = width
        }
        if let zoomed = zoomedTile(in: tiles) {
            frames[zoomed] = CGRect(x: viewport.minX + gap, y: viewport.minY + gap, width: usableWidth, height: max(viewport.height - 2 * gap, 0))
        }
        return frames
    }

    /// Focus, move, width and zoom in a tiled workspace. nil for actions that work as they do on the strip.
    private mutating func performTiled(_ action: Action) -> Bool? {
        keepTiledShape()
        if strip.isEmpty { return action == .toggleLayout || action == .toggleTabbed || action == .centerColumn ? nil : false }
        let changed = performTiledAction(action)
        // A zoom ends when focus leaves its tile.
        if let zoomed = zoomedWindow, strip.focusedColumn?.windows.contains(zoomed) != true { zoomedWindow = nil }
        return changed
    }

    private mutating func performTiledAction(_ action: Action) -> Bool? {
        switch action {
        case .focusColumnLeft: return focusTile(.left)
        case .focusColumnRight: return focusTile(.right)
        case .focusWindowUp: return focusTabOrTile(.up)
        case .focusWindowDown: return focusTabOrTile(.down)
        case .moveColumnLeft: return moveTile(.left)
        case .moveColumnRight: return moveTile(.right)
        case .moveWindowUp: return moveTile(.up)
        case .moveWindowDown: return moveTile(.down)
        case .focusFirstColumn: return strip.focusFirstColumn()
        case .focusLastColumn: return strip.focusLastColumn()
        case .consumeOrExpelLeft: return consumeOrExpelTile(.left)
        case .consumeOrExpelRight: return consumeOrExpelTile(.right)
        case .cycleColumnWidth: return cycleTiledRatio(forward: true)
        case .cycleColumnWidthBackward: return cycleTiledRatio(forward: false)
        case .toggleFullWidth:
            zoomedWindow = zoomedTile(in: tiles()) == nil ? strip.focusedWindow : nil
            return true
        default: return nil
        }
    }

    /// Moves focus to the tile next to the focused one on a side.
    private mutating func focusTile(_ side: TileSide) -> Bool {
        guard let target = TiledLayout.neighbour(of: tileFrames(tiles()), from: strip.focusedColumnIndex, side: side) else { return false }
        return strip.focusColumn(at: target)
    }

    /// Switches to the next tab of a focused tabbed tile that has one in that direction, else focuses the tile there.
    private mutating func focusTabOrTile(_ direction: VerticalDirection) -> Bool {
        if strip.focusedColumn?.isTabbed == true, strip.focusWindow(direction) { return true }
        return focusTile(direction == .up ? .up : .down)
    }

    /// Swaps the focused tile with the one next to it on a side; focus goes with the window.
    private mutating func moveTile(_ side: TileSide) -> Bool {
        guard let target = TiledLayout.neighbour(of: tileFrames(tiles()), from: strip.focusedColumnIndex, side: side) else { return false }
        return strip.swapColumns(strip.focusedColumnIndex, target)
    }

    /// A tab of a tabbed tile with other tabs is expelled into a new tile on that side. A window
    /// alone in its tile joins the tile on that side as a tab, making that tile tabbed so it stays one tile.
    private mutating func consumeOrExpelTile(_ direction: HorizontalDirection) -> Bool {
        guard let column = strip.focusedColumn else { return false }
        if column.windows.count > 1 { return strip.consumeOrExpel(direction) }
        let side: TileSide = direction == .left ? .left : .right
        guard let target = TiledLayout.neighbour(of: tileFrames(tiles()), from: strip.focusedColumnIndex, side: side) else { return false }
        return strip.joinColumn(at: target)
    }

    /// Steps the split that cuts the focused tile off from the tiles after it through 1/3, 1/2 and
    /// 2/3 of its room, for the tile's share of it. The last tile has no split of its own and
    /// changes the one before it.
    private mutating func cycleTiledRatio(forward: Bool) -> Bool {
        let count = strip.columns.count
        guard count >= 2 else { return false }
        let index = strip.focusedColumnIndex
        let split = min(index, count - 2)
        let current = TiledLayout.ratio(split: split, count: count, columns: tiledColumns, ratios: effectiveRatios(count))
        let isLast = index == count - 1
        let share = isLast ? 1 - current : current
        let presets = TiledLayout.ratioPresets
        let tolerance: CGFloat = 0.01
        let next = forward ? presets.first { $0 > share + tolerance } ?? presets[0]
                           : presets.last { $0 < share - tolerance } ?? presets[presets.count - 1]
        return setTiledRatio(split: split, count: count, to: isLast ? 1 - next : next)
    }

    /// Sets one split's ratio, keeping the others as they are. Returns false if it already was that.
    private mutating func setTiledRatio(split: Int, count: Int, to ratio: CGFloat) -> Bool {
        let current = effectiveRatios(count)
        var updated = (0..<(count - 1)).map { TiledLayout.isSet(split: $0, in: current) ? current![$0] : 0 }
        guard abs(updated[split] - ratio) >= 0.001 else { return false }
        updated[split] = ratio
        tiledRatios = updated
        return true
    }

    /// Where a window dropped at screen `x` lands among the tiles: after those whose middle is left of it.
    public func tileDropIndex(atX x: CGFloat) -> Int {
        tileFrames(tiles()).filter { $0.midX < x }.count
    }

    // MARK: Placement

    public func placements() -> [WindowPlacement] { layout == .tiled ? tiledPlacements() : scrollingPlacements() }

    private func tiledPlacements() -> [WindowPlacement] {
        let tiles = tiles()
        let frames = placedFrames(tiles)
        var result: [WindowPlacement] = []
        for (index, tile) in tiles.enumerated() {
            let column = strip.columns[tile.column]
            guard column.isTabbed else {
                result.append(WindowPlacement(window: column.windows[tile.row!], frame: frames[index], visibility: .visible))
                continue
            }
            let reserved = settings.tabBarHeight + settings.tabBarSpacing
            let shown = CGRect(x: frames[index].minX, y: frames[index].minY + reserved, width: frames[index].width, height: max(frames[index].height - reserved, 0))
            for (row, window) in column.windows.enumerated() {
                result.append(row == column.focusedRow
                    ? WindowPlacement(window: window, frame: shown, visibility: .visible)
                    : WindowPlacement(window: window, frame: hiddenFrame(size: shown.size), visibility: .hiddenTab))
            }
        }
        return result
    }

    private func scrollingPlacements() -> [WindowPlacement] {
        let gap = settings.gap
        let columnHeight = max(viewport.height - 2 * gap, 0)
        var result: [WindowPlacement] = []
        let widths = widths()
        let offsets = offsets(for: widths)

        for (index, column) in strip.columns.enumerated() {
            let width = widths[index]
            let (x, visibility) = position(width: width, offset: offsets[index])
            let top = viewport.minY + gap

            if column.isTabbed {
                let reserved = settings.tabBarHeight + settings.tabBarSpacing
                let shown = CGRect(x: x.rounded(), y: top + reserved, width: width, height: max(columnHeight - reserved, 0))
                for (row, window) in column.windows.enumerated() {
                    if row == column.focusedRow {
                        result.append(WindowPlacement(window: window, frame: shown, visibility: visibility))
                    } else {
                        result.append(WindowPlacement(window: window, frame: hiddenFrame(size: shown.size), visibility: .hiddenTab))
                    }
                }
                continue
            }

            let count = CGFloat(column.windows.count)
            let height = ((columnHeight - gap * (count - 1)) / count).rounded(.down)
            for (row, window) in column.windows.enumerated() {
                let frame = CGRect(x: x.rounded(), y: top + CGFloat(row) * (height + gap), width: width, height: height)
                result.append(WindowPlacement(window: window, frame: frame, visibility: visibility))
            }
        }
        return result
    }

    /// Tab bars for the tabbed columns that are at least partly on screen.
    public func tabBars() -> [TabBarPlacement] {
        if layout == .tiled {
            let tiles = tiles()
            let frames = placedFrames(tiles)
            return tiles.enumerated().compactMap { index, tile in
                let column = strip.columns[tile.column]
                guard column.isTabbed else { return nil }
                let frame = CGRect(x: frames[index].minX, y: frames[index].minY, width: frames[index].width, height: settings.tabBarHeight)
                return TabBarPlacement(column: tile.column, frame: frame, windows: column.windows, activeIndex: column.focusedRow)
            }
        }
        let widths = widths()
        let offsets = offsets(for: widths)
        return strip.columns.indices.compactMap { index in
            let column = strip.columns[index]
            let (x, visibility) = position(width: widths[index], offset: offsets[index])
            guard column.isTabbed, visibility == .visible || visibility == .partial else { return nil }
            let frame = CGRect(x: x.rounded(), y: viewport.minY + settings.gap, width: widths[index], height: settings.tabBarHeight)
            return TabBarPlacement(column: index, frame: frame, windows: column.windows, activeIndex: column.focusedRow)
        }
    }

    /// The window a dragged window joins when it is dropped at `point`: the active tab of a tab bar
    /// under the point, or the window under the point. nil when neither is there.
    public func dropTarget(at point: CGPoint, dragging window: WindowID) -> WindowID? {
        if let bar = tabBars().first(where: { $0.frame.contains(point) }) { return bar.activeWindow }
        return placements().first { placement in
            placement.window != window && (placement.visibility == .visible || placement.visibility == .partial) && placement.frame.contains(point)
        }?.window
    }

    /// Where a window dropped on `target` would go, to highlight while dragging: the tab bar
    /// with the window under it when `target`'s column is tabbed, else the whole column on screen.
    public func columnFrame(containing target: WindowID) -> CGRect? {
        guard let column = strip.location(of: target)?.column else { return nil }
        let windows = Set(strip.columns[column].windows)
        var frame = placements()
            .filter { windows.contains($0.window) && ($0.visibility == .visible || $0.visibility == .partial) }
            .map(\.frame).reduce(CGRect.null) { $0.union($1) }
        if let bar = tabBars().first(where: { $0.column == column }) { frame = frame.union(bar.frame) }
        return frame.isNull ? nil : frame.intersection(viewport)
    }

    /// A slim bar in the gap where a column inserted at `index` would go, for a drop between columns.
    public func insertionFrame(at index: Int, thickness: CGFloat = 4) -> CGRect {
        // Tiled, a dropped window takes a tile's place and pushes the rest on: show that tile.
        let tiles = layout == .tiled ? tiles() : []
        if !tiles.isEmpty { return tileFrames(tiles)[min(max(index, 0), tiles.count - 1)] }
        let offsets = columnOffsets()
        let edge = index < offsets.count ? offsets[index] : contentWidth + settings.gap
        let x = viewport.minX + settings.gap + edge - scrollOffset - settings.gap / 2
        let clamped = min(max(x, viewport.minX + thickness / 2), viewport.maxX - thickness / 2)
        return CGRect(x: (clamped - thickness / 2).rounded(), y: viewport.minY + settings.gap,
                      width: thickness, height: max(viewport.height - 2 * settings.gap, 0))
    }

    /// A column's left edge on screen, and whether it is visible or parked at an edge.
    private func position(width: CGFloat, offset: CGFloat) -> (x: CGFloat, visibility: Visibility) {
        let x = viewport.minX + settings.gap + offset - scrollOffset
        let overlap = min(x + width, viewport.maxX) - max(x, viewport.minX)
        if x >= viewport.minX - 0.5, x + width <= viewport.maxX + 0.5 {
            return (x, .visible)
        } else if overlap >= settings.sliver {
            return (x, .partial)
        } else if x + width / 2 < viewport.midX {
            return (viewport.minX - width + settings.sliver, .parkedLeft)
        } else {
            return (viewport.maxX - settings.sliver, .parkedRight)
        }
    }
}
