import Foundation
import Synchronization

/// The time stamped on library changes. Never repeats or goes back within a run, so two edits in quick
/// succession, even on two copies of the library, never share a `modifiedAt`; merging relies on that to see
/// that both changed.
public enum ChangeClock {
    private static let last = Mutex(Date.distantPast)

    public static func now() -> Date {
        last.withLock { last in
            let current = max(Date(), last.addingTimeInterval(0.001))
            last = current
            return current
        }
    }
}
