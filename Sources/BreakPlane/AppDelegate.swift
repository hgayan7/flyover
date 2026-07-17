import AppKit
import SwiftUI

/// Wires the tracker, scheduler, presenter, and the menu-bar UI together.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = SettingsStore()
    private let stats = StatsStore()

    private var tracker: ActivityTracker!
    private var scheduler: ReminderScheduler!
    private let presenter = PlanePresenter()

    private var statusItem: NSStatusItem!
    private let popover = NSPopover()

    func applicationDidFinishLaunching(_ notification: Notification) {
        scheduler = ReminderScheduler(settings: settings, stats: stats)
        tracker = ActivityTracker(stats: stats)

        scheduler.onFire = { [weak self] message in
            self?.presenter.fly(message: message)
        }
        tracker.onTick = { [weak self] in
            self?.scheduler.tick()
        }
        tracker.start()

        setupStatusItem()
        setupPopover()

        // Show a plane on launch so you can see it works right away.
        if ProcessInfo.processInfo.environment["BREAKPLANE_TESTFLY"] != nil {
            presenter.fly(message: "Time to take a break! ✈️")
        }
    }

    // MARK: Menu bar

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "airplane",
                                   accessibilityDescription: "BreakPlane")
            button.action = #selector(togglePopover(_:))
            button.target = self
        }
    }

    private func setupPopover() {
        popover.behavior = .transient
        let hosting = NSHostingController(
            rootView: PopoverView(
                settings: settings,
                stats: stats,
                onTestFly: { [weak self] in
                    self?.popover.performClose(nil)
                    self?.scheduler.flyNow()
                },
                onQuit: { NSApp.terminate(nil) }
            )
        )
        // Let the popover size itself to the SwiftUI content so it never overflows
        // the screen (otherwise it falls back to a large default size).
        hosting.sizingOptions = [.preferredContentSize]
        popover.contentViewController = hosting
    }

    @objc private func togglePopover(_ sender: Any?) {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        stats.save(force: true)
    }
}
