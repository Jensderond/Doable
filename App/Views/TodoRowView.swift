import SwiftUI
import SwiftData
import DoableCore

struct TodoRowView: View {
    @Bindable var store: TodoStore
    let item: TodoItem
    @Environment(\.modelContext) private var context
    @AppStorage("dueSoonWindow") private var windowRaw = DueSoonWindow.todayOnly.rawValue

    @State private var hovering = false
    @State private var showDeadlineEditor = false

    private var isPendingDone: Bool { store.pendingDone.contains(item.id) }
    private var window: DueSoonWindow { DueSoonWindow(rawValue: windowRaw) ?? .todayOnly }

    private var dueColor: Color? {
        guard !isPendingDone else { return nil }
        switch Classifier.itemState(dueDate: item.dueDate, now: Date(), window: window, calendar: .current) {
        case .overdue: return .red
        case .dueSoon: return .orange
        case .normal: return nil
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Button(action: toggleDone) {
                Image(systemName: isPendingDone ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isPendingDone ? Color.accentColor : Color.secondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .strikethrough(isPendingDone)
                    .foregroundStyle(titleColor)
                if let due = item.dueDate {
                    Text(due, format: .dateTime.weekday().month().day().hour().minute())
                        .font(.caption)
                        .foregroundStyle(dueColor ?? .secondary)
                }
            }

            Spacer(minLength: 8)

            if isPendingDone {
                Button("Undo") { store.undo(item) }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(Color.accentColor)
            } else if hovering || item.dueDate != nil {
                Button { showDeadlineEditor = true } label: {
                    Image(systemName: "clock")
                        .foregroundStyle(dueColor ?? .secondary)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showDeadlineEditor) {
                    DeadlineEditor(store: store, item: item, isPresented: $showDeadlineEditor)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
    }

    private var titleColor: Color {
        if isPendingDone { return .secondary }
        return dueColor ?? .primary
    }

    private func toggleDone() {
        if isPendingDone { store.undo(item) } else { store.markDone(item) }
    }
}
