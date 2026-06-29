import AppKit
import DoableCore
import SwiftData

/// Adds a right-click "Quit" menu to the menu bar icon.
///
/// `MenuBarExtra` owns its `NSStatusItem` and doesn't expose it, so we can't attach a menu
/// directly. Instead we install a local event monitor for right mouse-downs: when one lands on
/// the status-bar button, we pop up a small menu there and swallow the event. Left-clicks are
/// never touched, so `MenuBarExtra` still opens its window as before.
///
/// A right-click on the status item reaches our local monitor with `event.window` set to the
/// private `NSStatusBarWindow` hosting the button. The button sits a couple of levels deep in
/// that window's view tree (`NSStatusBarContentView` › `NSView` › `NSStatusBarButton`), so we
/// search the tree recursively to find it.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var rightClickMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        rightClickMonitor = NSEvent.addLocalMonitorForEvents(matching: .rightMouseDown) { [weak self] event in
            self?.handleRightMouseDown(event) ?? event
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            if case .new(title: let title) = DoableURL.parse(url) {
                Task { @MainActor in
                    TodoStore.shared.create(title: title, in: SharedContainer.shared.mainContext)
                }
            }
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
        guard let contentView = event.window?.contentView,
              let button = firstStatusBarButton(in: contentView) else { return event }

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

    /// Depth-first search for the `NSStatusBarButton` hosting our menu bar icon.
    private func firstStatusBarButton(in view: NSView) -> NSStatusBarButton? {
        if let button = view as? NSStatusBarButton { return button }
        for subview in view.subviews {
            if let button = firstStatusBarButton(in: subview) { return button }
        }
        return nil
    }
}
