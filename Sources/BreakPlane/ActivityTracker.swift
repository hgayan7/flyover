import Foundation
import CoreGraphics

/// Watches system-wide input idle time (keyboard/mouse) to tell whether you are
/// actively working. Uses `CGEventSource` idle time, which needs **no** accessibility
/// permission and reads nothing about *what* you type — only how long since any input.
@MainActor
final class ActivityTracker {
    private let stats: StatsStore
    private var timer: Timer?

    /// If there has been input within this many seconds, you count as "actively working".
    private let idleTimeout: Double = 60
    /// Idle at least this long is treated as a real break (resets the streak).
    private let breakThreshold: Double = 120
    private var breakRegistered = false

    /// Fired once per second after stats are updated.
    var onTick: (() -> Void)?

    init(stats: StatsStore) {
        self.stats = stats
    }

    func start() {
        timer?.invalidate()
        let t = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        t.tolerance = 0.2
        timer = t
    }

    private func idleSeconds() -> Double {
        // kCGAnyInputEventType == UInt32.max — "time since any input event".
        let anyEvent = CGEventType(rawValue: ~0)!
        return CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: anyEvent)
    }

    private func tick() {
        stats.rolloverIfNeeded()
        let idle = idleSeconds()

        if idle < idleTimeout {
            stats.addActiveSecond()
            breakRegistered = false
        } else if idle >= breakThreshold && !breakRegistered && stats.streakSeconds > 30 {
            // Stepped away long enough to count as a break.
            stats.registerBreak()
            breakRegistered = true
        }

        stats.save()          // throttled internally
        onTick?()
    }
}
