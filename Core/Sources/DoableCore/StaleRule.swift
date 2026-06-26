import Foundation

/// Determines whether an undated item has gone "stale" (sat untouched too long) and computes
/// the snooze date used by the Postpone action.
public enum StaleRule {
    /// True when the item has no deadline, is not currently snoozed, and at least
    /// `thresholdWorkdays` workdays have elapsed since `createdAt`.
    public static func isStale(createdAt: Date,
                               dueDate: Date?,
                               snoozeUntil: Date?,
                               now: Date,
                               thresholdWorkdays: Int,
                               calendar: Calendar) -> Bool {
        guard dueDate == nil else { return false }
        if let snoozeUntil, now < snoozeUntil { return false }
        return Workdays.workdaysElapsed(from: createdAt, to: now, calendar: calendar) >= thresholdWorkdays
    }

    /// The date until which the stale label should be suppressed after a Postpone.
    public static func snoozeDate(from now: Date, thresholdWorkdays: Int, calendar: Calendar) -> Date {
        Workdays.adding(thresholdWorkdays, workdaysTo: now, calendar: calendar)
    }
}
