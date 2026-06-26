import Foundation

/// Per-item due state. Stale-ness is handled separately (see StaleRule).
public enum ItemState: String, Sendable {
    case normal
    case dueSoon
    case overdue
}

public enum Classifier {
    /// Classifies an item by its deadline relative to `now`. Undated items are `.normal`.
    public static func itemState(dueDate: Date?, now: Date, window: DueSoonWindow, calendar: Calendar) -> ItemState {
        guard let dueDate else { return .normal }
        if dueDate < now { return .overdue }
        return isWithinWindow(dueDate: dueDate, now: now, window: window, calendar: calendar) ? .dueSoon : .normal
    }

    static func isWithinWindow(dueDate: Date, now: Date, window: DueSoonWindow, calendar: Calendar) -> Bool {
        switch window {
        case .todayOnly:
            return calendar.isDate(dueDate, inSameDayAs: now)
        case .oneHour:
            return dueDate <= now.addingTimeInterval(60 * 60)
        case .twentyFourHours:
            return dueDate <= now.addingTimeInterval(24 * 60 * 60)
        case .threeDays:
            return dueDate <= now.addingTimeInterval(3 * 24 * 60 * 60)
        }
    }
}
