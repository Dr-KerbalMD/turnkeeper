import CoreGraphics

/// Where a scroll event is in its gesture.
public enum TrackpadSwipePhase: Sendable {
    case began, changed, ended
    /// The scroll view's coasting after the fingers lift.
    case momentum
    /// A mouse wheel, which has no gesture phases.
    case none
}

/// Follows a two-finger trackpad swipe over a swipeable row on the Mac. The trackpad sends a swipe as scroll events,
/// which a drag gesture never sees, so the row reads them itself: a gesture that starts over the row and moves more
/// sideways than up and down slides the row and is kept from the scroll view around it; any other gesture scrolls.
public struct TrackpadSwipeTracker: Sendable {
    /// One scroll event, with the sideways movement measured in the direction the fingers moved.
    public struct Event: Sendable {
        public var phase: TrackpadSwipePhase
        public var fingerDeltaX: CGFloat = 0
        public var deltaY: CGFloat = 0
        /// Whether the pointer is over the row.
        public var isOverRow = false

        public init(phase: TrackpadSwipePhase, fingerDeltaX: CGFloat = 0, deltaY: CGFloat = 0,
                    isOverRow: Bool = false) {
            self.phase = phase
            self.fingerDeltaX = fingerDeltaX
            self.deltaY = deltaY
            self.isOverRow = isOverRow
        }
    }

    public enum Outcome: Equatable, Sendable {
        /// The event goes on to the scroll view.
        case pass
        /// The event is kept from the scroll view and needs nothing else.
        case consume
        /// The row slides to this sideways distance from where the swipe began; the event is kept.
        case slide(CGFloat)
        /// The fingers lifted after a sideways swipe; the event is kept.
        case finish
    }

    private var isTracking = false
    private var isSideways: Bool?
    private var translation: CGFloat = 0
    private var swallowsMomentum = false

    public init() {}

    public mutating func handle(_ event: Event) -> Outcome {
        switch event.phase {
        case .began:
            self = Self()
            isTracking = event.isOverRow
            return .pass
        case .changed:
            return change(by: event)
        case .ended:
            guard isTracking else { return .pass }
            isTracking = false
            swallowsMomentum = isSideways == true
            return swallowsMomentum ? .finish : .pass
        case .momentum:
            return swallowsMomentum ? .consume : .pass
        case .none:
            return .pass
        }
    }

    private mutating func change(by event: Event) -> Outcome {
        guard isTracking else { return .pass }
        if isSideways == nil, event.fingerDeltaX != 0 || event.deltaY != 0 {
            isSideways = abs(event.fingerDeltaX) > abs(event.deltaY)
        }
        guard isSideways == true else { return .pass }
        translation += event.fingerDeltaX
        return .slide(translation)
    }
}
