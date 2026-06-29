import Foundation
import SwiftData
import Observation
import DoableCore

/// Coordinates todo mutations and holds the transient "pending done" set used for the
/// undo-until-popover-closes behavior.
@Observable
final class TodoStore {
    /// IDs of items the user has checked off while the popover is open. Committed on close.
    var pendingDone: Set<UUID> = []

    func create(title: String, in context: ModelContext) {
        TodoStore.insert(title: title, into: context)
    }

    /// Trims, guards against empty, inserts a new active todo, and saves.
    static func insert(title: String, into context: ModelContext) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        context.insert(TodoItem(title: trimmed, createdAt: Date()))
        do { try context.save() } catch { print("SwiftData save failed: \(error)") }
    }

    func markDone(_ item: TodoItem) {
        pendingDone.insert(item.id)
    }

    func undo(_ item: TodoItem) {
        pendingDone.remove(item.id)
    }

    /// Permanently removes an item from the store.
    func delete(_ item: TodoItem, in context: ModelContext) {
        pendingDone.remove(item.id)
        context.delete(item)
        save(context)
    }

    /// Brings an already-committed completed item back to the active list.
    func restore(_ item: TodoItem, in context: ModelContext) {
        item.isDone = false
        item.completedAt = nil
        save(context)
    }

    /// Pins or unpins an item, moving it to (or away from) the top of the active list.
    func togglePin(_ item: TodoItem, in context: ModelContext) {
        item.isPinned.toggle()
        save(context)
    }

    func setDueDate(_ date: Date?, for item: TodoItem, in context: ModelContext) {
        item.dueDate = date
        if date != nil { item.staleSnoozeUntil = nil }
        save(context)
    }

    func postponeStale(_ item: TodoItem, now: Date, thresholdWorkdays: Int, calendar: Calendar, in context: ModelContext) {
        item.staleSnoozeUntil = StaleRule.snoozeDate(from: now, thresholdWorkdays: thresholdWorkdays, calendar: calendar)
        save(context)
    }

    /// Commits all pending-done items to the archive. Called when the popover closes.
    func commitPendingDone(in context: ModelContext) {
        guard !pendingDone.isEmpty else { return }
        let ids = pendingDone
        let descriptor = FetchDescriptor<TodoItem>(predicate: #Predicate { $0.isDone == false })
        let items: [TodoItem]
        do {
            items = try context.fetch(descriptor)
        } catch {
            print("commitPendingDone fetch failed, keeping pending items: \(error)")
            return
        }
        let now = Date()
        for item in items where ids.contains(item.id) {
            item.isDone = true
            item.completedAt = now
        }
        pendingDone.removeAll()
        save(context)
    }

    private func save(_ context: ModelContext) {
        do { try context.save() } catch { print("SwiftData save failed: \(error)") }
    }
}
