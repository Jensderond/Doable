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

    /// The task to show in the menu bar for a given scope, or `nil` when nothing qualifies.
    /// `.topTask` always surfaces the most urgent item; `.pinnedOnly` surfaces it only when it
    /// is pinned (which, given pinned items sort first, means "show only when something is pinned").
    public static func menuBarTask<T: Orderable>(_ items: [T], scope: MenuBarScope) -> T? {
        guard let top = mostUrgent(items) else { return nil }
        switch scope {
        case .topTask: return top
        case .pinnedOnly: return top.isPinned ? top : nil
        }
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

/// What the "show task in menu bar" option surfaces.
public enum MenuBarScope: String, CaseIterable, Sendable {
    /// The most urgent active task, pinned or not.
    case topTask
    /// Only a pinned (bookmarked) task; falls back to the plain status icon when none is pinned.
    case pinnedOnly

    public var displayName: String {
        switch self {
        case .topTask: return "Most urgent task"
        case .pinnedOnly: return "Bookmarked tasks only"
        }
    }
}
