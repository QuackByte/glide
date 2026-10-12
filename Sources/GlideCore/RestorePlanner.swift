import CoreGraphics

/// Chooses on-screen frames for windows when tiling stops, so nothing is left parked off screen.
public enum RestorePlanner {
    /// Windows already fully inside the viewport keep their frame. Mostly visible windows are
    /// nudged inside. The rest (parked columns) are cascaded from the top-left corner at up to
    /// `cascadeScale` of the viewport, so a stack of full-height windows still staggers.
    public static func restoredFrames(for frames: [(window: WindowID, frame: CGRect)], in viewport: CGRect, inset: CGFloat = 12, cascadeStep: CGFloat = 28, cascadeScale: CGFloat = 0.85) -> [WindowID: CGRect] {
        let bounds = viewport.insetBy(dx: inset, dy: inset)
        var result: [WindowID: CGRect] = [:]
        var cascadeIndex = 0

        for (window, frame) in frames {
            if viewport.contains(frame) {
                result[window] = frame
                continue
            }
            let overlap = frame.intersection(viewport)
            let mostlyVisible = !overlap.isNull && overlap.width >= frame.width / 2 && overlap.height >= frame.height / 2
            var size = CGSize(width: min(frame.width, bounds.width), height: min(frame.height, bounds.height))
            var origin: CGPoint
            if mostlyVisible {
                origin = frame.origin
            } else {
                size.width = min(size.width, (bounds.width * cascadeScale).rounded())
                size.height = min(size.height, (bounds.height * cascadeScale).rounded())
                let steps = Int(min(bounds.width - size.width, bounds.height - size.height) / cascadeStep)
                let step = CGFloat(cascadeIndex % (steps + 1))
                origin = CGPoint(x: bounds.minX + step * cascadeStep, y: bounds.minY + step * cascadeStep)
                cascadeIndex += 1
            }
            origin.x = min(max(origin.x, bounds.minX), bounds.maxX - size.width)
            origin.y = min(max(origin.y, bounds.minY), bounds.maxY - size.height)
            result[window] = CGRect(origin: origin, size: size)
        }
        return result
    }
}
