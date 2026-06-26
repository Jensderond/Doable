import SwiftUI
import SwiftData
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
            Image(systemName: "checklist")
        case .dueSoon:
            label(count: state.count, tint: .orange)
        case .overdue:
            label(count: state.count, tint: .red)
        }
    }

    private func label(count: Int, tint: Color) -> some View {
        HStack(spacing: 2) {
            Image(systemName: "checklist")
            Text("\(count)")
        }
        .foregroundStyle(tint)
    }
}
