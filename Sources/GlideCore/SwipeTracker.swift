/// One finger on the trackpad, in normalized coordinates (0…1, origin bottom-left).
public struct Touch: Equatable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

/// Recognizes horizontal multi-finger swipes from raw trackpad frames. Vertical swipes with
/// the same finger count (Mission Control, App Exposé) are left alone.
public struct SwipeTracker: Sendable {
    public enum Event: Equatable, Sendable {
        case began
        /// Horizontal movement since the previous event, in trackpad widths (negative is left).
        case changed(Double)
        /// Fingers lifted or changed count. Velocity in trackpad widths per second.
        case ended(velocity: Double)
    }

    private enum State: Sendable {
        case idle
        /// The right number of fingers is down but the direction isn't clear yet.
        case pending(startX: Double, startY: Double)
        case swiping(lastX: Double)
        /// Ignoring input until every finger lifts (wrong direction, or a swipe just ended).
        case locked
    }

    public var fingerCount: Int
    /// Distance the fingers must travel before a direction is decided.
    public var threshold: Double
    /// Samples within this window before release determine the velocity.
    public var velocityWindow: Double

    private var state: State = .idle
    private var samples: [(time: Double, x: Double)] = []

    public init(fingerCount: Int = 3, threshold: Double = 0.015, velocityWindow: Double = 0.08) {
        self.fingerCount = fingerCount
        self.threshold = threshold
        self.velocityWindow = velocityWindow
    }

    public var isSwiping: Bool {
        if case .swiping = state { true } else { false }
    }

    public mutating func update(touches: [Touch], at time: Double) -> [Event] {
        guard touches.count == fingerCount else {
            var events: [Event] = []
            switch state {
            case .swiping:
                events.append(.ended(velocity: velocity(at: time)))
                // Don't restart while the remaining fingers lift one by one.
                state = .locked
            case .pending, .idle:
                // Fingers land one at a time, so fewer than needed just means "not yet".
                // More than needed is someone else's gesture (macOS uses four fingers).
                state = touches.count > fingerCount ? .locked : .idle
            case .locked:
                break
            }
            if touches.isEmpty { state = .idle }
            samples = []
            return events
        }

        let x = touches.map(\.x).reduce(0, +) / Double(touches.count)
        let y = touches.map(\.y).reduce(0, +) / Double(touches.count)

        switch state {
        case .locked:
            return []
        case .idle:
            state = .pending(startX: x, startY: y)
            return []
        case let .pending(startX, startY):
            let dx = x - startX
            let dy = y - startY
            if abs(dx) >= threshold && abs(dx) > abs(dy) * 1.5 {
                state = .swiping(lastX: x)
                samples = [(time, x)]
                return [.began, .changed(dx)]
            }
            if abs(dy) >= threshold && abs(dy) >= abs(dx) {
                state = .locked
            }
            return []
        case let .swiping(lastX):
            state = .swiping(lastX: x)
            samples.append((time, x))
            samples.removeAll { $0.time < time - velocityWindow }
            return x == lastX ? [] : [.changed(x - lastX)]
        }
    }

    private func velocity(at time: Double) -> Double {
        let recent = samples.filter { $0.time >= time - velocityWindow }
        guard let first = recent.first, let last = recent.last, last.time - first.time >= 0.01 else { return 0 }
        return (last.x - first.x) / (last.time - first.time)
    }
}
