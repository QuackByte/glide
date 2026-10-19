import XCTest
@testable import GlideCore

/// The spiral geometry on its own.
final class TiledGeometryTests: XCTestCase {
    /// With a 12 pt gap the room is 1188 × 788.
    private let screen = CGRect(x: 0, y: 0, width: 1212, height: 812)

    private func frames(_ count: Int, _ columns: Int, ratios: [CGFloat]? = nil, in rect: CGRect? = nil, gap: CGFloat = 12) -> [CGRect] {
        TiledLayout.frames(in: rect ?? screen, count: count, columns: columns, gap: gap, ratios: ratios)
    }

    func testOneWindowFillsTheRoom() {
        XCTAssertEqual(frames(1, 2), [CGRect(x: 12, y: 12, width: 1188, height: 788)])
    }

    func testNoWindowsNoFrames() {
        XCTAssertEqual(frames(0, 2), [])
    }

    func testTwoColumns() {
        XCTAssertEqual(frames(2, 2), [CGRect(x: 12, y: 12, width: 588, height: 788), CGRect(x: 612, y: 12, width: 588, height: 788)])
    }

    func testTwoColumnsThenTheLastSplitsAlternately() {
        XCTAssertEqual(frames(3, 2), [CGRect(x: 12, y: 12, width: 588, height: 788), CGRect(x: 612, y: 12, width: 588, height: 388),
                                      CGRect(x: 612, y: 412, width: 588, height: 388)])
        XCTAssertEqual(frames(4, 2), [CGRect(x: 12, y: 12, width: 588, height: 788), CGRect(x: 612, y: 12, width: 588, height: 388),
                                      CGRect(x: 612, y: 412, width: 288, height: 388), CGRect(x: 912, y: 412, width: 288, height: 388)])
        XCTAssertEqual(frames(5, 2)[3], CGRect(x: 912, y: 412, width: 288, height: 188))
        XCTAssertEqual(frames(5, 2)[4], CGRect(x: 912, y: 612, width: 288, height: 188))
    }

    func testThreeColumnsAreThirds() {
        XCTAssertEqual(frames(3, 3), [CGRect(x: 12, y: 12, width: 388, height: 788), CGRect(x: 412, y: 12, width: 388, height: 788),
                                      CGRect(x: 812, y: 12, width: 388, height: 788)])
    }

    func testThreeColumnsThenTheLastSplits() {
        XCTAssertEqual(frames(4, 3), [CGRect(x: 12, y: 12, width: 388, height: 788), CGRect(x: 412, y: 12, width: 388, height: 788),
                                      CGRect(x: 812, y: 12, width: 388, height: 388), CGRect(x: 812, y: 412, width: 388, height: 388)])
        let five = frames(5, 3)
        XCTAssertEqual(five[3], CGRect(x: 812, y: 412, width: 188, height: 388))
        XCTAssertEqual(five[4], CGRect(x: 1012, y: 412, width: 188, height: 388))
    }

    func testTwoWindowsWithThreeColumnsAreHalves() {
        XCTAssertEqual(frames(2, 2), frames(2, 3))
    }

    func testFramesTileTheRoomWithExactGaps() {
        let screens: [(CGRect, CGFloat)] = [
            (screen, 12), (CGRect(x: 0, y: 0, width: 1920, height: 1080), 12), (CGRect(x: -1920, y: 30, width: 1920, height: 1050), 13),
            (CGRect(x: 0, y: 0, width: 3440, height: 1440), 24), (CGRect(x: 100, y: 50, width: 1001, height: 777), 7),
            (CGRect(x: 0, y: 0, width: 1366, height: 768), 0), (CGRect(x: 0, y: 40, width: 1537, height: 913), 19),
        ]
        for columns in [2, 3] {
            for count in 1...7 {
                for (rect, gap) in screens {
                    let frames = frames(count, columns, in: rect, gap: gap)
                    let context = "\(count) tiles, \(columns) columns, \(rect), gap \(gap)"
                    XCTAssertEqual(frames.count, count, context)
                    let room = CGRect(x: rect.minX + gap, y: rect.minY + gap, width: rect.width - 2 * gap, height: rect.height - 2 * gap)
                    for frame in frames {
                        for value in [frame.minX, frame.minY, frame.width, frame.height] { XCTAssertEqual(value, value.rounded(), context) }
                        XCTAssertTrue(frame.width > 0 && frame.height > 0, context)
                        XCTAssertTrue(room.contains(frame), "\(frame) is outside \(room): \(context)")
                    }
                    // The tiles reach every edge of the room.
                    XCTAssertEqual(frames.map(\.minX).min(), room.minX, context)
                    XCTAssertEqual(frames.map(\.maxX).max(), room.maxX, context)
                    XCTAssertEqual(frames.map(\.minY).min(), room.minY, context)
                    XCTAssertEqual(frames.map(\.maxY).max(), room.maxY, context)
                    // Nothing overlaps, and whatever faces a tile across a seam is exactly one gap away.
                    for a in frames.indices {
                        for b in frames.indices where b > a {
                            let overlapsX = min(frames[a].maxX, frames[b].maxX) - max(frames[a].minX, frames[b].minX) > 0
                            let overlapsY = min(frames[a].maxY, frames[b].maxY) - max(frames[a].minY, frames[b].minY) > 0
                            XCTAssertFalse(overlapsX && overlapsY, "\(frames[a]) overlaps \(frames[b]): \(context)")
                        }
                        for side in [TileSide.left, .right, .up, .down] {
                            guard let other = TiledLayout.neighbour(of: frames, from: a, side: side) else { continue }
                            let seam: CGFloat = switch side {
                            case .left: frames[a].minX - frames[other].maxX
                            case .right: frames[other].minX - frames[a].maxX
                            case .up: frames[a].minY - frames[other].maxY
                            case .down: frames[other].minY - frames[a].maxY
                            }
                            XCTAssertEqual(seam, gap, context)
                        }
                    }
                }
            }
        }
    }

    func testEqualColumnsDifferByAtMostAPoint() {
        for columns in [2, 3] {
            for count in 1...columns {
                let widths = frames(count, columns, in: CGRect(x: 0, y: 0, width: 1921, height: 1079)).map(\.width)
                XCTAssertLessThanOrEqual(widths.max()! - widths.min()!, 1, "\(widths)")
            }
        }
    }

    func testRatiosMoveASplitAndBadOnesAreIgnored() {
        XCTAssertEqual(frames(2, 2, ratios: [2.0 / 3])[0].width, 784)
        XCTAssertEqual(frames(2, 2, ratios: [1.0 / 3])[0].width, 392) // ⅓ of 1176
        let defaults = frames(4, 2)
        XCTAssertEqual(frames(4, 2, ratios: [0, 1.5, .nan]), defaults)
        XCTAssertEqual(frames(4, 2, ratios: []), defaults)
        XCTAssertEqual(frames(4, 2, ratios: nil), defaults)
        // Only the third split (3 | 4) changes; the first two keep their defaults.
        let changed = frames(4, 2, ratios: [0, 0, 0.25])
        XCTAssertEqual(changed[0], defaults[0])
        XCTAssertEqual(changed[1], defaults[1])
        XCTAssertEqual(changed[2].width, 144)
        XCTAssertEqual(changed[3].width, 432)
    }

    func testDefaultRatiosAndDirections() {
        XCTAssertEqual(TiledLayout.defaultRatio(split: 0, count: 3, columns: 3), 1.0 / 3)
        XCTAssertEqual(TiledLayout.defaultRatio(split: 1, count: 3, columns: 3), 0.5)
        XCTAssertEqual(TiledLayout.defaultRatio(split: 0, count: 2, columns: 3), 0.5)
        XCTAssertEqual(TiledLayout.defaultRatio(split: 0, count: 6, columns: 3), 1.0 / 3)
        XCTAssertEqual(TiledLayout.defaultRatio(split: 0, count: 6, columns: 2), 0.5)
        XCTAssertEqual(TiledLayout.defaultRatio(split: 4, count: 6, columns: 3), 0.5)
        // N=2: columns, then rows, columns, rows…; N=3: columns, columns, rows, columns…
        XCTAssertEqual((0..<4).map { TiledLayout.isSideBySide(split: $0, columns: 2) }, [true, false, true, false])
        XCTAssertEqual((0..<5).map { TiledLayout.isSideBySide(split: $0, columns: 3) }, [true, true, false, true, false])
    }

    func testAutoColumnsGoByTheScreensShape() {
        let shapes: [(CGFloat, CGFloat, Int)] = [
            (1920, 1080, 2), (2560, 1440, 2), (1366, 768, 2), (1080, 1920, 2),
            (3840, 1920, 3), // Exactly 2:1
            (3440, 1440, 3), (2560, 1080, 3), (5120, 1440, 3), (3000, 1501, 2),
        ]
        for (width, height, expected) in shapes {
            XCTAssertEqual(TiledLayout.autoColumns(for: CGRect(x: 0, y: 0, width: width, height: height)), expected, "\(width) × \(height)")
        }
        XCTAssertEqual(TiledLayout.autoColumns(for: .zero), 2)
    }

    func testNeighboursByGeometry() {
        let three = frames(3, 2) // [0][1 over 2]
        XCTAssertEqual(TiledLayout.neighbour(of: three, from: 0, side: .right), 1, "Tie between 1 and 2: the earlier")
        XCTAssertEqual(TiledLayout.neighbour(of: three, from: 2, side: .left), 0)
        XCTAssertEqual(TiledLayout.neighbour(of: three, from: 2, side: .up), 1)
        XCTAssertEqual(TiledLayout.neighbour(of: three, from: 1, side: .down), 2)
        XCTAssertNil(TiledLayout.neighbour(of: three, from: 0, side: .left))
        XCTAssertNil(TiledLayout.neighbour(of: three, from: 1, side: .up))
        XCTAssertNil(TiledLayout.neighbour(of: three, from: 2, side: .right))
        XCTAssertNil(TiledLayout.neighbour(of: three, from: 0, side: .down))

        let five = frames(5, 2) // [0][1 over (2 | (3 over 4))]
        XCTAssertEqual(TiledLayout.neighbour(of: five, from: 3, side: .left), 2)
        XCTAssertEqual(TiledLayout.neighbour(of: five, from: 4, side: .left), 2)
        XCTAssertEqual(TiledLayout.neighbour(of: five, from: 4, side: .up), 3)
        XCTAssertEqual(TiledLayout.neighbour(of: five, from: 2, side: .up), 1)
        XCTAssertEqual(TiledLayout.neighbour(of: five, from: 3, side: .up), 1)
        XCTAssertEqual(TiledLayout.neighbour(of: five, from: 1, side: .left), 0)
        XCTAssertNil(TiledLayout.neighbour(of: five, from: 2, side: .down))
        XCTAssertNil(TiledLayout.neighbour(of: [], from: 0, side: .left))
    }

    func testANeighbourNeedsToOverlapOnTheOtherAxis() {
        // Two stacked pairs with different dividers: the short top-right tile only faces the first tile on the left.
        let frames = [CGRect(x: 0, y: 0, width: 100, height: 50), CGRect(x: 0, y: 60, width: 100, height: 40),
                      CGRect(x: 110, y: 0, width: 100, height: 20), CGRect(x: 110, y: 30, width: 100, height: 70)]
        XCTAssertEqual(TiledLayout.neighbour(of: frames, from: 2, side: .left), 0)
        XCTAssertEqual(TiledLayout.neighbour(of: frames, from: 3, side: .left), 1, "Tiles 0 and 1 are both one gap away and overlap; 1 is closer in centre")
    }
}
