import Testing
import TurnkeeperKit

struct TrackpadSwipeTrackerTests {
    private typealias Event = TrackpadSwipeTracker.Event

    @Test func aSidewaysSwipeOverTheRowSlidesItAndFinishes() {
        var tracker = TrackpadSwipeTracker()
        #expect(tracker.handle(Event(phase: .began, isOverRow: true)) == .pass)
        #expect(tracker.handle(Event(phase: .changed, fingerDeltaX: -30, deltaY: 4)) == .slide(-30))
        // Once sideways, up-and-down movement doesn't hand the swipe back to the scroll view.
        #expect(tracker.handle(Event(phase: .changed, fingerDeltaX: -2, deltaY: 20)) == .slide(-32))
        #expect(tracker.handle(Event(phase: .ended)) == .finish)
        #expect(tracker.handle(Event(phase: .momentum, fingerDeltaX: -10)) == .consume)
    }

    @Test func anUpAndDownSwipeScrolls() {
        var tracker = TrackpadSwipeTracker()
        _ = tracker.handle(Event(phase: .began, isOverRow: true))
        #expect(tracker.handle(Event(phase: .changed, fingerDeltaX: 3, deltaY: -12)) == .pass)
        #expect(tracker.handle(Event(phase: .changed, fingerDeltaX: 40, deltaY: 0)) == .pass)
        #expect(tracker.handle(Event(phase: .ended)) == .pass)
        #expect(tracker.handle(Event(phase: .momentum, deltaY: -8)) == .pass)
    }

    @Test func aSwipeThatStartsElsewhereIsLeftAlone() {
        var tracker = TrackpadSwipeTracker()
        _ = tracker.handle(Event(phase: .began, isOverRow: false))
        #expect(tracker.handle(Event(phase: .changed, fingerDeltaX: 50)) == .pass)
        #expect(tracker.handle(Event(phase: .ended)) == .pass)
    }

    @Test func eventsWithoutMovementDecideNothingYet() {
        var tracker = TrackpadSwipeTracker()
        _ = tracker.handle(Event(phase: .began, isOverRow: true))
        #expect(tracker.handle(Event(phase: .changed)) == .pass)
        #expect(tracker.handle(Event(phase: .changed, fingerDeltaX: 25)) == .slide(25))
    }

    @Test func aNewSwipeStartsAfresh() {
        var tracker = TrackpadSwipeTracker()
        _ = tracker.handle(Event(phase: .began, isOverRow: true))
        _ = tracker.handle(Event(phase: .changed, fingerDeltaX: 60))
        _ = tracker.handle(Event(phase: .ended))
        _ = tracker.handle(Event(phase: .began, isOverRow: true))
        #expect(tracker.handle(Event(phase: .momentum)) == .pass)
        #expect(tracker.handle(Event(phase: .changed, fingerDeltaX: 5)) == .slide(5))
    }

    @Test func aMouseWheelAlwaysScrolls() {
        var tracker = TrackpadSwipeTracker()
        #expect(tracker.handle(Event(phase: .none, fingerDeltaX: 10, isOverRow: true)) == .pass)
    }
}
