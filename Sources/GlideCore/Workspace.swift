import CoreGraphics

/// How a workspace arranges its columns. Raw values are persisted; do not rename them.
public enum LayoutMode: String, CaseIterable, Codable, Sendable {
    /// Columns keep their preset widths on a strip that scrolls.
    case scrolling
    /// Columns share the screen width, so they all fit on screen.
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

    public init(gap: CGFloat = 12, sliver: CGFloat = 4, widthPresets: [CGFloat] = [1.0 / 3, 0.5, 2.0 / 3, 1], defaultWidthIndex: Int = 1,
                tabBarHeight: CGFloat = 28, tabBarSpacing: CGFloat = 4, defaultLayout: LayoutMode = .scrolling) {
        precondition(!widthPresets.isEmpty, "At least one width preset is required")
        self.gap = gap
        self.sliver = sliver
        self.widthPresets = widthPresets
        self.defaultWidthIndex = min(max(defaultWidthIndex, 0), widthPresets.count - 1)
        self.tabBarHeight = tabBarHeight
        self.tabBarSpacing = tabBarSpacing
        self.defaultLayout = defaultLayout
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

    public init(strip: Strip = Strip(), viewport: CGRect, settings: LayoutSettings = .standard) {
        self.strip = strip
        self.viewport = viewport
        self.settings = settings
    }

    public var layout: LayoutMode { layoutOverride ?? settings.defaultLayout }

    /// Switches between scrolling and tiled, for this workspace only.
    public mutating func toggleLayout() {
        layoutOverride = layout == .scrolling ? .tiled : .scrolling
        settleScroll()
    }

    // MARK: Geometry

    public var usableWidth: CGFloat { max(viewport.width - 2 * settings.gap, 0) }

    /// Where a hidden window of `size` waits: hidden tabs, and every window of an inactive
    /// workspace. macOS keeps part of a window on screen, so this leaves about a point showing.
    public func hiddenFrame(size: CGSize) -> CGRect {
        let x = hiddenCorner == .bottomRight ? viewport.maxX - 1 : viewport.minX - size.width + 1
        return CGRect(origin: CGPoint(x: x, y: viewport.maxY - 1), size: size)
    }

    public func width(ofColumn index: Int) -> CGFloat {
        layout == .tiled ? widths()[index] : scrollingWidth(ofColumn: index)
    }

    /// A column's width on the strip: its preset or custom width, at least as wide as its windows allow.
    private func scrollingWidth(ofColumn index: Int) -> CGFloat {
        let column = strip.columns[index]
        let preset = column.isFullWidth ? presetWidth(1) : weight(of: column)
        return min(max(preset, minimumWidth(of: column)), usableWidth)
    }

    /// What a column asks for: its custom width, else its preset's width. Tiled columns share the screen in this proportion.
    private func weight(of column: Column) -> CGFloat {
        let presets = settings.widthPresets
        return column.customWidth?.rounded() ?? presetWidth(presets[min(max(column.widthIndex, 0), presets.count - 1)])
    }

    private func minimumWidth(of column: Column) -> CGFloat {
        column.windows.compactMap { minimumWidths[$0] }.max() ?? 0
    }

    /// Every column's width, worked out once. Tiled columns split what's left after full-width ones.
    private func widths() -> [CGFloat] {
        let columns = strip.columns
        guard layout == .tiled else { return columns.indices.map(scrollingWidth) }

        var widths = [CGFloat](repeating: 0, count: columns.count)
        var shared: [Int] = []
        for index in columns.indices {
            if columns[index].isFullWidth { widths[index] = scrollingWidth(ofColumn: index) } else { shared.append(index) }
        }
        guard !shared.isEmpty else { return widths }

        // Columns split the room in proportion to their weights, but never below a window's minimum:
        // those keep their minimum and the rest share what remains.
        let room = usableWidth - settings.gap * CGFloat(shared.count - 1)
        let weights = Dictionary(uniqueKeysWithValues: shared.map { ($0, max(weight(of: columns[$0]), 1)) })
        var pinned: Set<Int> = []
        while true {
            let open = shared.filter { !pinned.contains($0) }
            let left = room - pinned.reduce(0) { $0 + minimumWidth(of: columns[$1]) }
            let total = open.reduce(0) { $0 + weights[$1]! }
            guard let squeezed = open.first(where: { minimumWidth(of: columns[$0]) > left * weights[$0]! / total }) else { break }
            pinned.insert(squeezed)
        }
        let remaining = room - pinned.reduce(0) { $0 + minimumWidth(of: columns[$1]) }
        let sharing = shared.filter { !pinned.contains($0) }
        let weightTotal = sharing.reduce(0) { $0 + weights[$1]! }
        for index in shared {
            widths[index] = pinned.contains(index) ? minimumWidth(of: columns[index]) : (remaining * weights[index]! / weightTotal).rounded()
        }
        // Rounding leaves a point or two over or short; the last shared column takes it so they fill the screen exactly.
        if let last = sharing.last {
            widths[last] = max(widths[last] + room - shared.reduce(0) { $0 + widths[$1] }, 1)
        }
        return widths.map { min($0, usableWidth) }
    }

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

    /// Scrolls as little as possible to bring the focused column fully on screen.
    public mutating func ensureFocusedVisible() {
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
        guard !strip.isEmpty else { return }
        let index = strip.focusedColumnIndex
        let widths = widths()
        scrollOffset = (offsets(for: widths)[index] + widths[index] / 2 - usableWidth / 2).rounded()
    }

    /// Removes empty space past either end of the strip, then keeps focus visible.
    /// Use after windows leave or the viewport changes.
    public mutating func settleScroll() {
        let maximum = max(contentWidth - usableWidth, 0)
        scrollOffset = min(max(scrollOffset, 0), maximum)
        ensureFocusedVisible()
    }

    // MARK: Gesture scrolling

    /// The scroll range that shows no empty space past the strip's ends.
    public var scrollBounds: ClosedRange<CGFloat> { 0...max(contentWidth - usableWidth, 0) }

    /// Moves the strip with the fingers. Past either end it follows at a third of the speed,
    /// up to a quarter of the screen, like a rubber band.
    public mutating func scroll(by delta: CGFloat) {
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
        guard !strip.isEmpty else {
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
            // Tiled columns fit on screen, so the strip goes back to the start when a zoomed column returns to its share.
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

    /// Gives the column holding `window` the width the user just dragged it to. On the strip that
    /// is its width; tiled, the width is a share of the screen, so it becomes the weight that lands
    /// the column near `width` with the other columns' weights unchanged. Returns false if the
    /// window isn't here.
    @discardableResult
    public mutating func setColumnWidthFromResize(_ window: WindowID, to width: CGFloat) -> Bool {
        guard layout == .tiled, let index = strip.location(of: window)?.column else {
            return strip.setCustomWidth(width, forColumnOf: window)
        }
        let others = strip.columns.indices.filter { $0 != index && !strip.columns[$0].isFullWidth }.map { weight(of: strip.columns[$0]) }
        guard !others.isEmpty else { return strip.setCustomWidth(width, forColumnOf: window) }
        // With W the wanted width, w / (w + others) = W / room, so w = W × others / (room - W).
        let room = usableWidth - settings.gap * CGFloat(others.count)
        let wanted = min(max(width, room * 0.1), room * 0.9)
        return strip.setCustomWidth(wanted * others.reduce(0, +) / (room - wanted), forColumnOf: window)
    }

    // MARK: Placement

    public func placements() -> [WindowPlacement] {
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
