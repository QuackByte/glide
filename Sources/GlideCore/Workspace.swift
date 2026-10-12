import CoreGraphics

public struct LayoutSettings: Equatable, Sendable {
    /// Space between columns, between stacked windows, and around the viewport edge.
    public var gap: CGFloat
    /// How much of an off-screen column stays visible at the screen edge.
    public var sliver: CGFloat
    /// Fractions of the viewport a column can take, cycled in order.
    public var widthPresets: [CGFloat]
    public var defaultWidthIndex: Int

    public init(gap: CGFloat = 12, sliver: CGFloat = 4, widthPresets: [CGFloat] = [1.0 / 3, 0.5, 2.0 / 3, 1], defaultWidthIndex: Int = 1) {
        precondition(!widthPresets.isEmpty, "At least one width preset is required")
        self.gap = gap
        self.sliver = sliver
        self.widthPresets = widthPresets
        self.defaultWidthIndex = min(max(defaultWidthIndex, 0), widthPresets.count - 1)
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
}

public struct WindowPlacement: Equatable, Sendable {
    public var window: WindowID
    public var frame: CGRect
    public var visibility: Visibility
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

    public init(strip: Strip = Strip(), viewport: CGRect, settings: LayoutSettings = .standard) {
        self.strip = strip
        self.viewport = viewport
        self.settings = settings
    }

    // MARK: Geometry

    public var usableWidth: CGFloat { max(viewport.width - 2 * settings.gap, 0) }

    /// Preset fractions are of the whole viewport, so two ½ columns exactly fill it, gaps included.
    public func width(ofColumn index: Int) -> CGFloat {
        let column = strip.columns[index]
        let presets = settings.widthPresets
        let fraction = column.isFullWidth ? 1 : presets[min(max(column.widthIndex, 0), presets.count - 1)]
        let preset = ((viewport.width - settings.gap) * fraction - settings.gap).rounded()
        let minimum = column.windows.compactMap { minimumWidths[$0] }.max() ?? 0
        return min(max(preset, minimum), usableWidth)
    }

    /// The strip coordinate of each column's left edge.
    public func columnOffsets() -> [CGFloat] {
        var offsets: [CGFloat] = []
        var x: CGFloat = 0
        for index in strip.columns.indices {
            offsets.append(x)
            x += width(ofColumn: index) + settings.gap
        }
        return offsets
    }

    public var contentWidth: CGFloat {
        guard let last = strip.columns.indices.last else { return 0 }
        return columnOffsets()[last] + width(ofColumn: last)
    }

    // MARK: Scrolling

    /// Scrolls as little as possible to bring the focused column fully on screen.
    public mutating func ensureFocusedVisible() {
        guard !strip.isEmpty else {
            scrollOffset = 0
            return
        }
        let index = strip.focusedColumnIndex
        let left = columnOffsets()[index]
        let right = left + width(ofColumn: index)
        if left < scrollOffset {
            scrollOffset = left
        } else if right > scrollOffset + usableWidth {
            scrollOffset = right - usableWidth
        }
    }

    public mutating func centerFocusedColumn() {
        guard !strip.isEmpty else { return }
        let index = strip.focusedColumnIndex
        scrollOffset = (columnOffsets()[index] + width(ofColumn: index) / 2 - usableWidth / 2).rounded()
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
        let offsets = columnOffsets()
        var candidates: [CGFloat] = [bounds.lowerBound, bounds.upperBound]
        for index in strip.columns.indices {
            candidates.append(offsets[index])
            candidates.append(offsets[index] + width(ofColumn: index) - usableWidth)
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
        let offsets = columnOffsets()
        func fullyVisible(_ index: Int) -> Bool {
            offsets[index] >= scrollOffset - 0.5 && offsets[index] + width(ofColumn: index) <= scrollOffset + usableWidth + 0.5
        }
        let current = strip.focusedColumnIndex
        guard !fullyVisible(current) else { return false }
        let middle = scrollOffset + usableWidth / 2
        let candidates = strip.columns.indices.filter(fullyVisible)
        let nearest = (candidates.isEmpty ? Array(strip.columns.indices) : candidates).min {
            abs(offsets[$0] + width(ofColumn: $0) / 2 - middle) < abs(offsets[$1] + width(ofColumn: $1) / 2 - middle)
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
        case .cycleColumnWidth: changed = strip.cycleWidth(presetCount: settings.widthPresets.count)
        case .cycleColumnWidthBackward: changed = strip.cycleWidth(presetCount: settings.widthPresets.count, forward: false)
        case .toggleFullWidth: changed = strip.toggleFullWidth()
        case .centerColumn:
            let before = scrollOffset
            centerFocusedColumn()
            return scrollOffset != before
        case .toggleFloating, .toggleTiling:
            return false
        }
        if changed {
            if action == .consumeOrExpelLeft || action == .consumeOrExpelRight {
                settleScroll()
            } else {
                ensureFocusedVisible()
            }
        }
        return changed
    }

    // MARK: Placement

    public func placements() -> [WindowPlacement] {
        let gap = settings.gap
        let offsets = columnOffsets()
        let top = viewport.minY + gap
        let columnHeight = max(viewport.height - 2 * gap, 0)
        var result: [WindowPlacement] = []

        for (index, column) in strip.columns.enumerated() {
            let width = width(ofColumn: index)
            var x = viewport.minX + gap + offsets[index] - scrollOffset
            let overlap = min(x + width, viewport.maxX) - max(x, viewport.minX)
            let visibility: Visibility
            if x >= viewport.minX - 0.5, x + width <= viewport.maxX + 0.5 {
                visibility = .visible
            } else if overlap >= settings.sliver {
                visibility = .partial
            } else if x + width / 2 < viewport.midX {
                visibility = .parkedLeft
                x = viewport.minX - width + settings.sliver
            } else {
                visibility = .parkedRight
                x = viewport.maxX - settings.sliver
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
}
