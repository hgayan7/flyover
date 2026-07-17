import Foundation
import Combine

// MARK: - Settings (persisted, user-configurable)

/// User-configurable reminder settings. Modes are independent toggles that can be
/// combined — whichever enabled mode becomes due first flies the plane.
@MainActor
final class SettingsStore: ObservableObject {
    @Published var remindersEnabled: Bool { didSet { save() } }

    /// Fire after a continuous stretch of active work (idle time resets the streak).
    @Published var activeStreakEnabled: Bool { didSet { save() } }
    @Published var activeStreakSeconds: Int { didSet { save() } }

    /// Fire every N seconds of wall-clock time since the last reminder, regardless of activity.
    @Published var fixedIntervalEnabled: Bool { didSet { save() } }
    @Published var fixedIntervalSeconds: Int { didSet { save() } }

    private let key = "Flyover.settings.v1"

    private struct Snapshot: Codable {
        var remindersEnabled: Bool
        var activeStreakEnabled: Bool
        var activeStreakSeconds: Int
        var fixedIntervalEnabled: Bool
        var fixedIntervalSeconds: Int
    }

    init() {
        // Sensible defaults: gentle nudge after ~50 min of continuous work.
        var snap = Snapshot(
            remindersEnabled: true,
            activeStreakEnabled: true,
            activeStreakSeconds: 50 * 60,
            fixedIntervalEnabled: false,
            fixedIntervalSeconds: 60 * 60
        )
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode(Snapshot.self, from: data) {
            snap = decoded
        }
        remindersEnabled = snap.remindersEnabled
        activeStreakEnabled = snap.activeStreakEnabled
        activeStreakSeconds = snap.activeStreakSeconds
        fixedIntervalEnabled = snap.fixedIntervalEnabled
        fixedIntervalSeconds = snap.fixedIntervalSeconds
    }

    private func save() {
        let snap = Snapshot(
            remindersEnabled: remindersEnabled,
            activeStreakEnabled: activeStreakEnabled,
            activeStreakSeconds: activeStreakSeconds,
            fixedIntervalEnabled: fixedIntervalEnabled,
            fixedIntervalSeconds: fixedIntervalSeconds
        )
        if let data = try? JSONEncoder().encode(snap) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

// MARK: - Stats (persisted, resets each day)

/// Today's working numbers. Everything is on-device; nothing leaves the machine.
@MainActor
final class StatsStore: ObservableObject {
    @Published private(set) var activeSeconds: Int = 0      // total active time today
    @Published private(set) var streakSeconds: Int = 0      // current unbroken active stretch
    @Published private(set) var breaksTaken: Int = 0        // idle stretches counted as breaks today
    @Published var nextReminderInSeconds: Int = -1          // -1 == no reminder scheduled

    private var dayKey: String = ""
    private var lastSave = Date.distantPast
    private let key = "Flyover.stats.v1"

    private struct Snapshot: Codable {
        var dayKey: String
        var activeSeconds: Int
        var streakSeconds: Int
        var breaksTaken: Int
    }

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let snap = try? JSONDecoder().decode(Snapshot.self, from: data) {
            dayKey = snap.dayKey
            activeSeconds = snap.activeSeconds
            streakSeconds = snap.streakSeconds
            breaksTaken = snap.breaksTaken
        }
        rolloverIfNeeded()
    }

    private func todayKey() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    /// Wipe the day's counters when the calendar date changes.
    func rolloverIfNeeded() {
        let today = todayKey()
        guard today != dayKey else { return }
        dayKey = today
        activeSeconds = 0
        streakSeconds = 0
        breaksTaken = 0
        save(force: true)
    }

    func addActiveSecond() {
        activeSeconds += 1
        streakSeconds += 1
    }

    func registerBreak() {
        breaksTaken += 1
        streakSeconds = 0
    }

    /// Called by the scheduler when a reminder fires — the current stretch ends.
    func resetStreak() {
        streakSeconds = 0
    }

    func save(force: Bool = false) {
        if !force && Date().timeIntervalSince(lastSave) < 15 { return }
        lastSave = Date()
        let snap = Snapshot(dayKey: dayKey, activeSeconds: activeSeconds,
                            streakSeconds: streakSeconds, breaksTaken: breaksTaken)
        if let data = try? JSONEncoder().encode(snap) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
