import Foundation

/// Anything sortable in the active list. The app's SwiftData model conforms to this.
public protocol Orderable {
    var dueDate: Date? { get }
    var createdAt: Date { get }
}

public enum Ordering {
    /// Active-list order: dated items first (soonest deadline ascending); undated items after;
    /// newest-first (`createdAt` descending) as the tiebreaker and among undated items.
    public static func activeSorted<T: Orderable>(_ items: [T]) -> [T] {
        items.sorted { lhs, rhs in
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
}
