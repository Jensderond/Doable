import Foundation
import SwiftData
import Observation
import DoableCore

/// Coordinates todo mutations and holds the transient "pending done" set used for the
/// undo-until-popover-closes behavior.
@Observable
final class TodoStore {
    /// Shared instance used by entry points that don't have access to the SwiftUI environment
    /// (e.g. AppDelegate URL handler).
    @MainActor static let shared = TodoStore()

    /// IDs of items the user has checked off while the popover is open. Committed on close.
    var pendingDone: Set<UUID> = []

    func create(title: String, in context: ModelContext) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let item = TodoItem(title: trimmed, createdAt: Date())
        context.insert(item)

        // Place the new (unpinned) item at the top of the unpinned section.
        let items = activeItems(in: context)
        guard let moving = items.firstIndex(where: { $0.id == item.id }) else {
            save(context); return
        }
        let order = Reorder.placeAtTopOfSection(pinFlags: items.map(\.isPinned), moving: moving)
        renumber(items, by: order, in: context)
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

    /// Pins or unpins an item, then moves it to the top of its new section so the change
    /// is visible and the manual order stays consistent (pinned always above unpinned).
    func togglePin(_ item: TodoItem, in context: ModelContext) {
        let items = activeItems(in: context)
        guard let moving = items.firstIndex(where: { $0.id == item.id }) else { return }
        item.isPinned.toggle() // `items` holds the same reference, so the flag below reflects this.
        let order = Reorder.placeAtTopOfSection(pinFlags: items.map(\.isPinned), moving: moving)
        renumber(items, by: order, in: context)
    }

    /// Applies a drag-reorder. `from`/`to` index into the current visual order
    /// (`Ordering.activeSorted` of the active items); `to` is the post-removal insertion index.
    func move(from: Int, to: Int, in context: ModelContext) {
        let items = activeItems(in: context)
        guard items.indices.contains(from) else { return }
        let plan = Reorder.move(pinFlags: items.map(\.isPinned), from: from, to: to)
        for (originalIndex, item) in items.enumerated() {
            item.isPinned = plan.pinned[originalIndex]
        }
        renumber(items, by: plan.order, in: context)
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

    /// Fetches the active (not done) items in current visual order.
    private func activeItems(in context: ModelContext) -> [TodoItem] {
        let descriptor = FetchDescriptor<TodoItem>(predicate: #Predicate { $0.isDone == false })
        let items = (try? context.fetch(descriptor)) ?? []
        return Ordering.activeSorted(items)
    }

    /// Writes `sortIndex = visual position` for `items` reordered by `order`
    /// (indices into `items`), then saves.
    private func renumber(_ items: [TodoItem], by order: [Int], in context: ModelContext) {
        for (position, originalIndex) in order.enumerated() {
            items[originalIndex].sortIndex = position
        }
        save(context)
    }

    private func save(_ context: ModelContext) {
        do { try context.save() } catch { print("SwiftData save failed: \(error)") }
    }
}
