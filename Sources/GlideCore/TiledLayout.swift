import CoreGraphics

/// Which way to look from a tile for its neighbour.
public enum TileSide: Sendable {
    case left, right, up, down
}

/// The tiled layout's geometry, from counts alone. Tiles are placed in order like a dwindle: the
/// first `columns - 1` tiles each take a column, then the last column's room is split again and
/// again for the rest, top/bottom first and then left/right, alternating. Split `k` is the one
/// that cuts tile `k` off from the room left for the tiles after it.
public enum TiledLayout {
    public static let minColumns = 2
    public static let maxColumns = 3

    /// The share of a split's room the cycling shortcut steps through for the first tile.
    public static let ratioPresets: [CGFloat] = [1.0 / 3, 0.5, 2.0 / 3]

    public static func clampColumns(_ columns: Int) -> Int { min(max(columns, minColumns), maxColumns) }

    /// Three columns on ultrawide screens (at least twice as wide as tall), else two.
    public static func autoColumns(for viewport: CGRect) -> Int {
        viewport.height > 0 && viewport.width / viewport.height >= 2.0 ? maxColumns : minColumns
    }

    /// Whether split `split` puts its two parts side by side (a column split) rather than one above the other.
    public static func isSideBySide(split: Int, columns: Int) -> Bool {
        let columns = clampColumns(columns)
        return split < columns - 1 || (split - (columns - 1)) % 2 == 1
    }

    /// What the first part of a split gets by default, nominally: an equal share of the columns
    /// still to place (a third, then a half, with three columns), else half. Laying out gives the
    /// columns exactly equal widths, gaps taken out; see `frames`.
    public static func defaultRatio(split: Int, count: Int, columns: Int) -> CGFloat {
        let levels = min(count, clampColumns(columns))
        return split < levels - 1 ? 1 / CGFloat(levels - split) : 0.5
    }

    /// Whether `ratios` holds a usable ratio for a split, rather than leaving it at its default.
    public static func isSet(split: Int, in ratios: [CGFloat]?) -> Bool {
        guard let ratios, ratios.indices.contains(split) else { return false }
        return ratios[split] > 0 && ratios[split] < 1
    }

    /// A split's ratio: the one in `ratios` if it holds a usable value for it, else the default.
    public static func ratio(split: Int, count: Int, columns: Int, ratios: [CGFloat]?) -> CGFloat {
        isSet(split: split, in: ratios) ? ratios![split] : defaultRatio(split: split, count: count, columns: columns)
    }

    /// The room each split divides, in order. `viewport` gets `gap` all around its edge, like the strip.
    public static func splits(in viewport: CGRect, count: Int, columns: Int, gap: CGFloat, ratios: [CGFloat]? = nil) -> [(room: CGRect, sideBySide: Bool)] {
        walk(viewport, count: count, columns: columns, gap: gap, ratios: ratios).splits
    }

    /// One frame per tile, in order. Whole points, with exactly `gap` between neighbours and
    /// around the edge, and no overlap. `ratios` sets what the first part of each split gets, as a
    /// share of the room less one gap (see `ratio`); splits it doesn't cover, or holds 0 for, take
    /// their default: equal columns, else half.
    public static func frames(in viewport: CGRect, count: Int, columns: Int, gap: CGFloat, ratios: [CGFloat]? = nil) -> [CGRect] {
        walk(viewport, count: count, columns: columns, gap: gap, ratios: ratios).frames
    }

    private static func walk(_ viewport: CGRect, count: Int, columns: Int, gap: CGFloat, ratios: [CGFloat]?) -> (frames: [CGRect], splits: [(room: CGRect, sideBySide: Bool)]) {
        var frames: [CGRect] = []
        var splits: [(room: CGRect, sideBySide: Bool)] = []
        guard count > 0 else { return (frames, splits) }
        let gap = gap.rounded()
        let columns = clampColumns(columns)
        var room = CGRect(x: viewport.minX.rounded() + gap, y: viewport.minY.rounded() + gap,
                          width: max(viewport.width.rounded() - 2 * gap, 0), height: max(viewport.height.rounded() - 2 * gap, 0))

        for split in 0..<(count - 1) {
            let sideBySide = isSideBySide(split: split, columns: columns)
            splits.append((room, sideBySide))
            let length = sideBySide ? room.width : room.height
            let available = max(length - gap, 0)
            let wanted = firstPart(split: split, count: count, columns: columns, length: length, available: available, gap: gap, ratios: ratios)
            let first = min(max(wanted.rounded(), 0), available)
            let rest = available - first
            if sideBySide {
                frames.append(CGRect(x: room.minX, y: room.minY, width: first, height: room.height))
                room = CGRect(x: room.minX + first + gap, y: room.minY, width: rest, height: room.height)
            } else {
                frames.append(CGRect(x: room.minX, y: room.minY, width: room.width, height: first))
                room = CGRect(x: room.minX, y: room.minY + first + gap, width: room.width, height: rest)
            }
        }
        frames.append(room)
        return (frames, splits)
    }

    /// The size of a split's first part: the set ratio of the room, else an equal share of the columns left, else half.
    private static func firstPart(split: Int, count: Int, columns: Int, length: CGFloat, available: CGFloat, gap: CGFloat, ratios: [CGFloat]?) -> CGFloat {
        if isSet(split: split, in: ratios) { return available * ratios![split] }
        let left = min(count, columns) - split
        return left > 1 ? (length - CGFloat(left - 1) * gap) / CGFloat(left) : available / 2
    }

    /// The tile next to `from` on a side: among those whose edge faces it and that overlap its span
    /// along the other axis, the nearest edge; ties go to the one whose centre is closest along the
    /// other axis, then the earlier tile. nil when nothing is that way.
    public static func neighbour(of frames: [CGRect], from: Int, side: TileSide) -> Int? {
        guard frames.indices.contains(from) else { return nil }
        let source = frames[from]
        var best: Int?
        var bestKey: (edge: CGFloat, centre: CGFloat) = (0, 0)
        for (index, other) in frames.enumerated() where index != from {
            let distance: CGFloat
            let overlap: CGFloat
            switch side {
            case .left: (distance, overlap) = (source.minX - other.maxX, span(source.minY, source.maxY, other.minY, other.maxY))
            case .right: (distance, overlap) = (other.minX - source.maxX, span(source.minY, source.maxY, other.minY, other.maxY))
            case .up: (distance, overlap) = (source.minY - other.maxY, span(source.minX, source.maxX, other.minX, other.maxX))
            case .down: (distance, overlap) = (other.minY - source.maxY, span(source.minX, source.maxX, other.minX, other.maxX))
            }
            if distance < -0.5 || overlap <= 0 { continue }
            // Centres are compared along the other axis, to within a point, so a near tie goes to the earlier tile.
            let offCentre = side == .left || side == .right ? abs(other.midY - source.midY) : abs(other.midX - source.midX)
            let key = (edge: max(distance, 0), centre: offCentre)
            if best == nil || key.edge < bestKey.edge - 0.5 || (abs(key.edge - bestKey.edge) <= 0.5 && key.centre < bestKey.centre - 1) {
                best = index
                bestKey = key
            }
        }
        return best
    }

    private static func span(_ aMin: CGFloat, _ aMax: CGFloat, _ bMin: CGFloat, _ bMax: CGFloat) -> CGFloat {
        min(aMax, bMax) - max(aMin, bMin)
    }
}
