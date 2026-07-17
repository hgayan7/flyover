import Foundation

/// Decides *when* to fly the plane, based on the enabled (and combinable) modes.
/// Evaluated once per tracker tick.
@MainActor
final class ReminderScheduler {
    private let settings: SettingsStore
    private let stats: StatsStore

    /// Called with a human-readable message when it's break time.
    var onFire: ((String) -> Void)?

    private var lastFireWall: TimeInterval

    init(settings: SettingsStore, stats: StatsStore) {
        self.settings = settings
        self.stats = stats
        self.lastFireWall = Date().timeIntervalSince1970
    }

    func tick() {
        let now = Date().timeIntervalSince1970
        var soonest = Int.max
        var due = false

        if settings.activeStreakEnabled {
            let remaining = settings.activeStreakSeconds - stats.streakSeconds
            soonest = min(soonest, remaining)
            if remaining <= 0 { due = true }
        }
        if settings.fixedIntervalEnabled {
            let elapsed = Int(now - lastFireWall)
            let remaining = settings.fixedIntervalSeconds - elapsed
            soonest = min(soonest, remaining)
            if remaining <= 0 { due = true }
        }

        // Surface the countdown for the menu-bar glance.
        stats.nextReminderInSeconds = (soonest == Int.max) ? -1 : max(0, soonest)

        guard settings.remindersEnabled,
              settings.activeStreakEnabled || settings.fixedIntervalEnabled else { return }
        if due { fire(message: dueMessage()) }
    }

    /// Fly a plane on demand (from the menu bar), independent of the schedule.
    func flyNow() {
        onFire?(dueMessage())
    }

    private func fire(message: String) {
        onFire?(message)
        lastFireWall = Date().timeIntervalSince1970
        stats.resetStreak()
    }

    /// A fresh, varied "take a break" message each time it fires.
    private func dueMessage() -> String {
        let minutes = max(1, stats.streakSeconds / 60)
        let lines = [
            "Time to take a break! ✈️",
            "Take a break — you've focused \(minutes) min straight",
            "\(minutes) min in — stand up and stretch those legs! 🦵",
            "Break time! Look 20 ft away for 20 sec 👀",
            "Step away and breathe — take a break ☕️",
            "You've earned a break after \(minutes) min ✈️",
            "Rest your eyes — time for a quick break 😌"
        ]
        return lines.randomElement() ?? lines[0]
    }
}
