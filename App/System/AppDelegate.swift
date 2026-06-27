import AppKit

/// Adds a right-click "Quit" menu to the menu bar icon.
///
/// `MenuBarExtra` owns its `NSStatusItem` and doesn't expose it, so we can't attach a menu
/// directly. Instead we install a local event monitor for right mouse-downs: when one lands on
/// the status-bar button, we pop up a small menu there and swallow the event. Left-clicks are
/// never touched, so `MenuBarExtra` still opens its window as before.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var rightClickMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        rightClickMonitor = NSEvent.addLocalMonitorForEvents(matching: .rightMouseDown) { [weak self] event in
            self?.handleRightMouseDown(event) ?? event
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let monitor = rightClickMonitor {
            NSEvent.removeMonitor(monitor)
            rightClickMonitor = nil
        }
    }

    /// Returns `nil` to consume the event when it's a right-click on our status item (we showed
    /// the menu), or the original event to let everything else propagate normally.
    private func handleRightMouseDown(_ event: NSEvent) -> NSEvent? {
        guard let button = statusBarButton(in: event.window) else { return event }
        let menu = NSMenu()
        let quit = NSMenuItem(title: "Quit Doable",
                              action: #selector(NSApplication.terminate(_:)),
                              keyEquivalent: "q")
        quit.target = NSApp
        menu.addItem(quit)
        menu.popUp(positioning: nil,
                   at: NSPoint(x: 0, y: button.bounds.height + 4),
                   in: button)
        return nil
    }

    /// The status-bar button hosting our menu bar icon, if `window` is its status-bar window.
    private func statusBarButton(in window: NSWindow?) -> NSStatusBarButton? {
        guard let contentView = window?.contentView else { return nil }
        if let button = contentView as? NSStatusBarButton { return button }
        return contentView.subviews.compactMap { $0 as? NSStatusBarButton }.first
    }
}
