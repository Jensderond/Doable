import SwiftUI
import SwiftData
import DoableCore

struct TodoRowView: View {
    @Bindable var store: TodoStore
    let item: TodoItem
    @Binding var editingItemID: UUID?
    @Environment(\.modelContext) private var context
    @AppStorage("dueSoonWindow") private var windowRaw = DueSoonWindow.todayOnly.rawValue
    @AppStorage("staleThresholdWorkdays") private var staleThreshold = 3
    @AppStorage("dateEditorPlacement") private var placementRaw = DateEditorPlacement.overlay.rawValue

    @State private var hovering = false

    private var isPendingDone: Bool { store.pendingDone.contains(item.id) }
    private var window: DueSoonWindow { DueSoonWindow(rawValue: windowRaw) ?? .todayOnly }
    private var placement: DateEditorPlacement { DateEditorPlacement(rawValue: placementRaw) ?? .overlay }
    private var isEditing: Bool { editingItemID == item.id }

    private var isStale: Bool {
        guard !isPendingDone else { return false }
        return StaleRule.isStale(createdAt: item.createdAt,
                                 dueDate: item.dueDate,
                                 snoozeUntil: item.staleSnoozeUntil,
                                 now: Date(),
                                 thresholdWorkdays: staleThreshold,
                                 calendar: .current)
    }

    private var dueColor: Color? {
        guard !isPendingDone else { return nil }
        switch Classifier.itemState(dueDate: item.dueDate, now: Date(), window: window, calendar: .current) {
        case .overdue: return .red
        case .dueSoon: return .orange
        case .normal: return nil
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            rowContent
            if placement == .inline && isEditing {
                DeadlineEditor(store: store, item: item, onDismiss: { editingItemID = nil })
                    .padding(.horizontal, 10)
                    .padding(.bottom, 8)
            }
        }
    }

    private var rowContent: some View {
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
                if isStale {
                    HStack(spacing: 6) {
                        Text("Stale")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Color.secondary.opacity(0.2), in: Capsule())
                            .foregroundStyle(.secondary)
                        Button("Postpone") {
                            store.postponeStale(item, now: Date(), thresholdWorkdays: staleThreshold, calendar: .current, in: context)
                        }
                        .buttonStyle(.plain)
                        .font(.caption2)
                        .foregroundStyle(Color.accentColor)
                    }
                }
            }

            Spacer(minLength: 8)

            if isPendingDone {
                Button("Undo") { store.undo(item) }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(Color.accentColor)
            } else if hovering || item.dueDate != nil {
                Button { editingItemID = item.id } label: {
                    Image(systemName: "clock")
                        .foregroundStyle(dueColor ?? .secondary)
                }
                .buttonStyle(.plain)
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
