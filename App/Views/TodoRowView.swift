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

    @State private var hovering = false

    private var isPendingDone: Bool { store.pendingDone.contains(item.id) }
    private var window: DueSoonWindow { DueSoonWindow(rawValue: windowRaw) ?? .todayOnly }
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
            if isEditing {
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
                    .fontWeight(item.isPinned ? .bold : .regular)
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
            } else {
                HStack(spacing: 10) {
                    // Pinned items always show the (filled) pin so the state is visible; unpinned
                    // items reveal the pin button on hover.
                    if item.isPinned || hovering {
                        Button { store.togglePin(item, in: context) } label: {
                            Image(systemName: item.isPinned ? "bookmark.fill" : "bookmark")
                                .foregroundStyle(item.isPinned ? Color.accentColor : Color.secondary)
                        }
                        .buttonStyle(.plain)
                        .help(item.isPinned ? "Unpin" : "Pin to top")
                    }
                    // The "…" menu is always present, anchoring the right edge so the bookmark's
                    // position never shifts on hover. It folds in the deadline, pin, and delete
                    // actions that used to be split between the inline clock and the context menu.
                    Menu {
                        Button { editingItemID = item.id } label: {
                            Label(item.dueDate == nil ? "Set deadline" : "Edit deadline",
                                  systemImage: "clock")
                        }
                        Button { store.togglePin(item, in: context) } label: {
                            Label(item.isPinned ? "Unpin" : "Pin to top",
                                  systemImage: item.isPinned ? "bookmark.slash" : "bookmark")
                        }
                        Divider()
                        Button(role: .destructive) {
                            if editingItemID == item.id { editingItemID = nil }
                            store.delete(item, in: context)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundStyle(dueColor ?? .secondary)
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .contextMenu {
            Button {
                store.togglePin(item, in: context)
            } label: {
                Label(item.isPinned ? "Unpin" : "Pin to top",
                      systemImage: item.isPinned ? "bookmark.slash" : "bookmark")
            }
            Button(role: .destructive) {
                if editingItemID == item.id { editingItemID = nil }
                store.delete(item, in: context)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private var titleColor: Color {
        if isPendingDone { return .secondary }
        return dueColor ?? .primary
    }

    private func toggleDone() {
        if isPendingDone { store.undo(item) } else {
            store.markDone(item)
            if editingItemID == item.id { editingItemID = nil }
        }
    }
}
