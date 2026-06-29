import Foundation

/// Anything sortable in the active list. The app's SwiftData model conforms to this.
public protocol Orderable {
    var dueDate: Date? { get }
    var createdAt: Date { get }
    var isPinned: Bool { get }
    var sortIndex: Int { get }
}

extension Orderable {
    /// Defaults so lightweight conformances (e.g. tests) need not specify them.
    public var isPinned: Bool { false }
    public var sortIndex: Int { 0 }
}

public enum Ordering {
    /// Active-list order: pinned items first; then by the user's manual `sortIndex`
    /// (ascending — lower sorts higher). `createdAt` descending is the final tiebreaker,
    /// which also gives a stable initial order for migrated stores where every item ties
    /// at `sortIndex == 0`.
    public static func activeSorted<T: Orderable>(_ items: [T]) -> [T] {
        items.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
            if lhs.sortIndex != rhs.sortIndex { return lhs.sortIndex < rhs.sortIndex }
            return lhs.createdAt > rhs.createdAt
        }
    }

    /// The single task to surface in the menu bar: the top of the active list (the user's
    /// manual top — first pinned item, otherwise the first unpinned). `nil` when empty.
    public static func mostUrgent<T: Orderable>(_ items: [T]) -> T? {
        activeSorted(items).first
    }

    /// The task to show in the menu bar for a given scope, or `nil` when nothing qualifies.
    /// `.topTask` surfaces the manual top; `.pinnedOnly` surfaces it only when it is pinned
    /// (which, given pinned items sort first, means "show only when something is pinned").
    public static func menuBarTask<T: Orderable>(_ items: [T], scope: MenuBarScope) -> T? {
        guard let top = mostUrgent(items) else { return nil }
        switch scope {
        case .topTask: return top
        case .pinnedOnly: return top.isPinned ? top : nil
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
