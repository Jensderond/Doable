import SwiftUI
import SwiftData
import DoableCore

struct MenuBarLabel: View {
    @Query(filter: #Predicate<TodoItem> { $0.isDone == false }) private var items: [TodoItem]
    @AppStorage("dueSoonWindow") private var windowRaw = DueSoonWindow.todayOnly.rawValue

    private var window: DueSoonWindow { DueSoonWindow(rawValue: windowRaw) ?? .todayOnly }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let state = MenuBarStateCalculator.state(items: items, now: context.date, window: window, calendar: .current)
            content(for: state)
        }
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
