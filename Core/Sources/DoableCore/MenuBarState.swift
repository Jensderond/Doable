import Foundation

public enum Severity: String, Sendable {
    case normal
    case dueSoon
    case overdue
}

public struct MenuBarState: Equatable, Sendable {
    public let severity: Severity
    public let count: Int
    public init(severity: Severity, count: Int) {
        self.severity = severity
        self.count = count
    }
}

public enum MenuBarStateCalculator {
    /// Aggregates active items: severity is the worst present (overdue > dueSoon > normal);
    /// count is the number of items that are due-soon or overdue.
    public static func state<T: Orderable>(items: [T], now: Date, window: DueSoonWindow, calendar: Calendar) -> MenuBarState {
        var count = 0
        var hasOverdue = false
        var hasDueSoon = false
        for item in items {
            switch Classifier.itemState(dueDate: item.dueDate, now: now, window: window, calendar: calendar) {
            case .overdue:
                hasOverdue = true
                count += 1
            case .dueSoon:
                hasDueSoon = true
                count += 1
            case .normal:
                break
            }
        }
        let severity: Severity = hasOverdue ? .overdue : (hasDueSoon ? .dueSoon : .normal)
        return MenuBarState(severity: severity, count: count)
    }
}
