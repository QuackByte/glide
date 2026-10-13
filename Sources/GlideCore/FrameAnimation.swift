import CoreGraphics

/// Timing and interpolation for moving windows between layouts.
public enum FrameAnimation {
    /// Short enough to feel instant, long enough to show where a column went.
    public static let defaultDuration: Double = 0.12

    /// Cubic ease-out: fast start, gentle landing.
    public static func easeOut(_ t: Double) -> Double {
        let clamped = min(max(t, 0), 1)
        return 1 - pow(1 - clamped, 3)
    }

    /// Size jumps to the target immediately; only the origin travels. Resizing every frame
    /// makes apps re-layout their content and stutter.
    public static func frame(from: CGRect, to: CGRect, progress: Double) -> CGRect {
        let p = CGFloat(easeOut(progress))
        return CGRect(
            x: (from.minX + (to.minX - from.minX) * p).rounded(),
            y: (from.minY + (to.minY - from.minY) * p).rounded(),
            width: to.width,
            height: to.height
        )
    }

    /// Animate only moves the user can see: a window going from one parked spot to another
    /// (both off screen) just jumps, as do moves of a pixel or two.
    public static func shouldAnimate(from: CGRect, to: CGRect, in viewport: CGRect, minimumVisible: CGFloat = 8) -> Bool {
        guard abs(from.minX - to.minX) > 1 || abs(from.minY - to.minY) > 1 else { return false }
        func visible(_ rect: CGRect) -> Bool {
            let overlap = rect.intersection(viewport)
            return !overlap.isNull && overlap.width >= minimumVisible
        }
        return visible(from) || visible(to)
    }
}
