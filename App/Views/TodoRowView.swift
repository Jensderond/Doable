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
                    Text(due, format: .dateTime.weekday().month().day())
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
            } else {
                HStack(spacing: 10) {
                    // Stale items get a quiet, always-visible glyph instead of a badge row,
                    // so stale rows stay the same height as normal rows.
                    if isStale {
                        Image(systemName: "hourglass")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .help("Stale — untouched for \(staleThreshold) workday\(staleThreshold == 1 ? "" : "s")")
                    }
                    // The bookmark always occupies its slot so the title never rewraps
                    // (and the click target never shifts) when it fades in on hover.
                    // Pinned items keep it visible; unpinned items reveal it on hover.
                    Button { store.togglePin(item, in: context) } label: {
                        Image(systemName: item.isPinned ? "bookmark.fill" : "bookmark")
                            .foregroundStyle(item.isPinned ? Color.accentColor : Color.secondary)
                    }
                    .buttonStyle(.plain)
                    .help(item.isPinned ? "Unpin" : "Pin to top")
                    .opacity(item.isPinned || hovering ? 1 : 0)
                    .allowsHitTesting(item.isPinned || hovering)
                    // The "…" menu folds in the deadline, pin, and delete actions that used to
                    // be split between the inline clock and the context menu.
                    Menu {
                        if isStale {
                            Button {
                                store.postponeStale(item, now: Date(), thresholdWorkdays: staleThreshold, calendar: .current, in: context)
                            } label: {
                                Label("Postpone", systemImage: "hourglass")
                            }
                            Divider()
                        }
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
            if isStale {
                Button {
                    store.postponeStale(item, now: Date(), thresholdWorkdays: staleThreshold, calendar: .current, in: context)
                } label: {
                    Label("Postpone", systemImage: "hourglass")
                }
                Divider()
            }
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
