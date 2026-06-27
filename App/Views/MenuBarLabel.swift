import SwiftUI
import SwiftData
import AppKit
import DoableCore

struct MenuBarLabel: View {
    @Query(filter: #Predicate<TodoItem> { $0.isDone == false }) private var items: [TodoItem]
    @AppStorage("dueSoonWindow") private var windowRaw = DueSoonWindow.todayOnly.rawValue

    /// Recomputed once a minute so the icon reflects items crossing into due-soon/overdue as
    /// time passes, even when no item data changes. A plain timer is used instead of
    /// `TimelineView`, which self-retriggers an infinite update loop inside a `MenuBarExtra`
    /// label (pegs CPU and leaks memory).
    @State private var now = Date()
    private let ticker = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    private var window: DueSoonWindow { DueSoonWindow(rawValue: windowRaw) ?? .todayOnly }

    var body: some View {
        let state = MenuBarStateCalculator.state(items: items, now: now, window: window, calendar: .current)
        content(for: state)
            .onReceive(ticker) { now = $0 }
    }

    @ViewBuilder
    private func content(for state: MenuBarState) -> some View {
        switch state.severity {
        case .normal:
            // Template image so it adapts to the menu bar's light/dark appearance.
            Image(systemName: "checklist")
        case .dueSoon:
            coloredLabel(count: state.count, tint: .orange)
        case .overdue:
            coloredLabel(count: state.count, tint: .red)
        }
    }

    /// macOS renders a `MenuBarExtra` label's SF Symbols/text as a template image and tints it
    /// to match the menu bar, which strips `foregroundStyle`. To keep the warning color we
    /// rasterize the tinted view into a *non-template* `NSImage` — the system leaves its colors
    /// alone. Falls back to the plain styled view if rendering fails.
    @ViewBuilder
    private func coloredLabel(count: Int, tint: Color) -> some View {
        let label = HStack(spacing: 2) {
            Image(systemName: "checklist")
            Text("\(count)")
        }
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(tint)

        if let image = render(label) {
            Image(nsImage: image)
        } else {
            label
        }
    }

    private func render(_ view: some View) -> NSImage? {
        let renderer = ImageRenderer(content: view)
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2
        guard let image = renderer.nsImage else { return nil }
        image.isTemplate = false
        return image
    }
}
