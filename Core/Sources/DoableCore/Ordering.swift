import Foundation

/// Anything sortable in the active list. The app's SwiftData model conforms to this.
public protocol Orderable {
    var dueDate: Date? { get }
    var createdAt: Date { get }
    var isPinned: Bool { get }
}

extension Orderable {
    /// Defaults to unpinned so lightweight conformances (e.g. tests) need not specify it.
    public var isPinned: Bool { false }
}

public enum Ordering {
    /// Active-list order: pinned items first; then dated items (soonest deadline ascending);
    /// undated items after; newest-first (`createdAt` descending) as the tiebreaker and among
    /// undated items. Pinning takes precedence over deadlines, but the same deadline rules apply
    /// within the pinned and unpinned groups.
    public static func activeSorted<T: Orderable>(_ items: [T]) -> [T] {
        items.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
            return deadlinePrecedes(lhs, rhs)
        }
    }

    /// The single task to surface in the menu bar: the top of the active list (pinned first,
    /// otherwise the soonest deadline). `nil` when there are no active items.
    public static func mostUrgent<T: Orderable>(_ items: [T]) -> T? {
        activeSorted(items).first
    }

    private static func deadlinePrecedes<T: Orderable>(_ lhs: T, _ rhs: T) -> Bool {
        switch (lhs.dueDate, rhs.dueDate) {
        case let (l?, r?):
            if l != r { return l < r }
            return lhs.createdAt > rhs.createdAt
        case (.some, .none):
            return true
        case (.none, .some):
            return false
        case (.none, .none):
            return lhs.createdAt > rhs.createdAt
        }
    }
}
