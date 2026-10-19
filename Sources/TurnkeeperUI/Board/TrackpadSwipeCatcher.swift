#if os(macOS)
import AppKit
import SwiftUI
import TurnkeeperKit

/// Two-finger trackpad swipes for `SwipeableStrip` on the Mac, read from the window's scroll events
/// (`TrackpadSwipeTracker`). Put it behind the strip: it takes no clicks, and only sees where the pointer is.
struct TrackpadSwipeCatcher: NSViewRepresentable {
    /// The sideways distance the fingers have moved since the swipe began.
    let slide: (CGFloat) -> Void
    let finish: () -> Void

    func makeNSView(context: Context) -> CatcherView {
        CatcherView()
    }

    func updateNSView(_ view: CatcherView, context: Context) {
        view.slide = slide
        view.finish = finish
    }

    static func dismantleNSView(_ view: CatcherView, coordinator: ()) {
        view.stopMonitoring()
    }

    final class CatcherView: NSView {
        var slide: (CGFloat) -> Void = { _ in }
        var finish: () -> Void = {}
        private var monitor: Any?
        private var tracker = TrackpadSwipeTracker()

        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            stopMonitoring()
            guard window != nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                guard let self else { return event }
                return handle(event)
            }
        }

        func stopMonitoring() {
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
        }

        /// The event, or nil when the swipe keeps it from the scroll view.
        private func handle(_ event: NSEvent) -> NSEvent? {
            guard event.window === window else { return event }
            switch tracker.handle(Self.swipeEvent(event, isOverRow: isOver(event))) {
            case .pass:
                return event
            case .consume:
                return nil
            case let .slide(distance):
                slide(distance)
                return nil
            case .finish:
                finish()
                return nil
            }
        }

        private func isOver(_ event: NSEvent) -> Bool {
            bounds.contains(convert(event.locationInWindow, from: nil))
        }

        private static func swipeEvent(_ event: NSEvent, isOverRow: Bool) -> TrackpadSwipeTracker.Event {
            // With natural scrolling the deltas follow the fingers; otherwise they run the other way.
            let fingerDeltaX = event.isDirectionInvertedFromDevice ? event.scrollingDeltaX : -event.scrollingDeltaX
            return TrackpadSwipeTracker.Event(phase: phase(of: event), fingerDeltaX: fingerDeltaX,
                                              deltaY: event.scrollingDeltaY, isOverRow: isOverRow)
        }

        private static func phase(of event: NSEvent) -> TrackpadSwipePhase {
            if !event.momentumPhase.isEmpty { return .momentum }
            if event.phase.contains(.began) { return .began }
            if event.phase.contains(.changed) { return .changed }
            if event.phase.contains(.ended) || event.phase.contains(.cancelled) { return .ended }
            return .none
        }
    }
}
#endif
