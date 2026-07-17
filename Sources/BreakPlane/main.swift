import AppKit

// Entry point. A menu-bar-only app: no dock icon, no main window.
// Top-level code runs on the main thread; assume main-actor isolation so we can
// construct the (main-actor-isolated) AppDelegate directly.
MainActor.assumeIsolated {
    let delegate = AppDelegate()
    let app = NSApplication.shared
    app.delegate = delegate                 // NSApplication holds this weakly...
    app.setActivationPolicy(.accessory)     // .accessory == LSUIElement, no dock icon
    app.run()                               // ...but `delegate` stays alive here until quit
}
