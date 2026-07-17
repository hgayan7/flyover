import SwiftUI

/// The menu-bar popover: today's glance, the on/off switch, mode settings, and actions.
struct PopoverView: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var stats: StatsStore
    var onTestFly: () -> Void
    var onQuit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            Divider()
            glance
            Divider()
            modes
            Divider()
            footer
        }
        .padding(16)
        .frame(width: 300)
    }

    // MARK: Header

    private var header: some View {
        HStack {
            Image(systemName: "airplane")
                .font(.title2)
                .foregroundStyle(.tint)
            Text("Flyover")
                .font(.headline)
            Spacer()
            Toggle("", isOn: $settings.remindersEnabled)
                .toggleStyle(.switch)
                .labelsHidden()
                .help("Turn break reminders on or off")
        }
    }

    // MARK: Stats glance

    private var glance: some View {
        VStack(alignment: .leading, spacing: 8) {
            statRow("Worked today", value: hms(stats.activeSeconds), icon: "clock")
            statRow("Current streak", value: hms(stats.streakSeconds), icon: "flame")
            statRow("Breaks taken", value: "\(stats.breaksTaken)", icon: "cup.and.saucer")
            statRow("Next reminder", value: nextText, icon: "bell")
        }
    }

    private func statRow(_ label: String, value: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .frame(width: 18)
                .foregroundStyle(.secondary)
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(.body, design: .rounded).monospacedDigit())
                .fontWeight(.semibold)
        }
    }

    private var nextText: String {
        guard settings.remindersEnabled else { return "off" }
        let s = stats.nextReminderInSeconds
        if s < 0 { return "—" }
        if s == 0 { return "any moment" }
        return "in " + hms(s)
    }

    // MARK: Mode settings

    private var modes: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("REMIND ME")
                .font(.caption2).fontWeight(.bold)
                .foregroundStyle(.secondary)

            Toggle(isOn: $settings.activeStreakEnabled) {
                Text("After continuous work")
            }
            if settings.activeStreakEnabled {
                minutesStepper(value: $settings.activeStreakSeconds, range: 10...180, step: 5)
            }

            Toggle(isOn: $settings.fixedIntervalEnabled) {
                Text("Every fixed interval")
            }
            if settings.fixedIntervalEnabled {
                minutesStepper(value: $settings.fixedIntervalSeconds, range: 10...180, step: 5)
            }
        }
        .disabled(!settings.remindersEnabled)
        .opacity(settings.remindersEnabled ? 1 : 0.5)
    }

    private func minutesStepper(value: Binding<Int>, range: ClosedRange<Int>, step: Int) -> some View {
        let minutes = Binding<Int>(
            get: { value.wrappedValue / 60 },
            set: { value.wrappedValue = $0 * 60 }
        )
        return Stepper(value: minutes, in: range, step: step) {
            Text("\(minutes.wrappedValue) min")
                .font(.system(.body, design: .rounded).monospacedDigit())
        }
        .padding(.leading, 20)
    }

    // MARK: Footer

    private var footer: some View {
        HStack {
            Button {
                onTestFly()
            } label: {
                Label("Fly now", systemImage: "paperplane.fill")
            }
            Spacer()
            Button(role: .destructive) {
                onQuit()
            } label: {
                Text("Quit")
            }
        }
    }

    // MARK: Helpers

    private func hms(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 { return String(format: "%dh %02dm", h, m) }
        if m > 0 { return String(format: "%dm %02ds", m, s) }
        return "\(s)s"
    }
}
