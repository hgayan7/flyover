import AppKit
import SceneKit

/// Owns the transparent, click-through overlay window and drives the fly-through.
@MainActor
final class PlanePresenter {
    private var window: NSWindow?
    private var fallback: Timer?

    /// Fly a plane across the screen with the given banner text. No-op if one is already flying.
    func fly(message: String) {
        guard window == nil else { return }
        guard let screen = NSScreen.main else { return }
        let frame = screen.frame

        let win = NSWindow(contentRect: frame, styleMask: .borderless,
                           backing: .buffered, defer: false)
        win.isOpaque = false
        win.backgroundColor = .clear
        win.hasShadow = false
        win.level = .floating
        win.ignoresMouseEvents = true          // clicks pass straight through
        win.collectionBehavior = [.canJoinAllSpaces, .stationary,
                                  .fullScreenAuxiliary, .ignoresCycle]
        win.isReleasedWhenClosed = false

        let sceneView = SCNView(frame: NSRect(origin: .zero, size: frame.size))
        sceneView.backgroundColor = .clear
        sceneView.autoenablesDefaultLighting = false
        sceneView.antialiasingMode = .multisampling4X
        sceneView.rendersContinuously = true
        sceneView.preferredFramesPerSecond = 60

        let builder = PlaneScene(aspect: frame.width / max(frame.height, 1))
        sceneView.scene = builder.makeScene(message: message) { [weak self] in
            self?.dismiss()
        }

        win.contentView = sceneView
        win.orderFrontRegardless()
        window = win

        // Safety net in case the animation completion never fires.
        fallback?.invalidate()
        fallback = Timer.scheduledTimer(withTimeInterval: builder.duration + 3,
                                        repeats: false) { [weak self] _ in
            Task { @MainActor in self?.dismiss() }
        }
    }

    private func dismiss() {
        fallback?.invalidate()
        fallback = nil
        window?.orderOut(nil)
        window = nil
    }
}
