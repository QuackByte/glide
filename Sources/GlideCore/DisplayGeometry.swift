import CoreGraphics

/// Decisions about several displays, from their frames alone (AX coordinates, top-left origin).
public enum DisplayGeometry {
    /// The display next to `current` going left (-1) or right (+1), by horizontal position; nil at the end.
    public static func neighbour(of current: Int, direction: Int, in displays: [CGRect]) -> Int? {
        let ordered = displays.indices.sorted { (displays[$0].midX, displays[$0].midY) < (displays[$1].midX, displays[$1].midY) }
        guard let position = ordered.firstIndex(of: current) else { return nil }
        let next = position + direction
        return ordered.indices.contains(next) ? ordered[next] : nil
    }

    /// Whether a window at `frame` would show on a display other than `own`.
    public static func showsOnAnother(_ frame: CGRect, own: Int, in displays: [CGRect]) -> Bool {
        displays.indices.contains { index in
            guard index != own else { return false }
            let overlap = displays[index].intersection(frame)
            return !overlap.isNull && overlap.width > 1 && overlap.height > 1
        }
    }

    /// The bottom corner of a display that hidden windows can wait in without showing on another
    /// display: bottom-right unless a display lies beyond it, then bottom-left.
    public static func hiddenCorner(of index: Int, in displays: [CGRect]) -> HiddenCorner {
        let display = displays[index]
        let far: CGFloat = 100_000
        let pastRight = CGRect(x: display.maxX - 1, y: display.maxY - 1, width: far, height: far)
        let pastLeft = CGRect(x: display.minX - far, y: display.maxY - 1, width: far + 1, height: far)
        if showsOnAnother(pastRight, own: index, in: displays), !showsOnAnother(pastLeft, own: index, in: displays) {
            return .bottomLeft
        }
        return .bottomRight
    }

    /// The display holding most of `frame`; nil if it's on none.
    public static func display(containing frame: CGRect, in displays: [CGRect]) -> Int? {
        let areas = displays.map { display -> CGFloat in
            let overlap = display.intersection(frame)
            return overlap.isNull ? 0 : overlap.width * overlap.height
        }
        guard let best = areas.indices.max(by: { areas[$0] < areas[$1] }), areas[best] > 0 else { return nil }
        return best
    }

    /// Whether a window at `frame` covers a whole display, as a video player or game does when it
    /// takes the screen without macOS's full screen. Where Glide itself put the window (`placed`)
    /// doesn't count: with no gap and the menu bar hidden, a full-width column covers the display too.
    public static func coversDisplay(_ frame: CGRect, in displays: [CGRect], placed: CGRect? = nil, tolerance: CGFloat = 2) -> Bool {
        func close(_ a: CGRect, _ b: CGRect) -> Bool {
            abs(a.minX - b.minX) <= tolerance && abs(a.minY - b.minY) <= tolerance
                && abs(a.width - b.width) <= tolerance && abs(a.height - b.height) <= tolerance
        }
        if let placed, close(frame, placed) { return false }
        return displays.contains { close(frame, $0) }
    }

    /// The display a point is on; nil if it's on none.
    public static func display(at point: CGPoint, in displays: [CGRect]) -> Int? {
        displays.firstIndex { $0.contains(point) }
    }
}

extension Workspace {
    /// The column index a window dropped at screen `x` lands at: before the first column whose
    /// middle is right of it.
    public func dropIndex(atX x: CGFloat) -> Int {
        let offsets = columnOffsets()
        let stripX = x - viewport.minX - settings.gap + scrollOffset
        return strip.columns.indices.filter { offsets[$0] + width(ofColumn: $0) / 2 < stripX }.count
    }
}
