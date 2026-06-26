import Foundation

/// Weekend-skipping date arithmetic. Saturdays and Sundays (per the supplied calendar) are not workdays.
public enum Workdays {
    /// Advances `date` by `count` workdays, preserving time-of-day. `count` must be >= 0.
    public static func adding(_ count: Int, workdaysTo date: Date, calendar: Calendar) -> Date {
        guard count > 0 else { return date }
        var result = date
        var remaining = count
        while remaining > 0 {
            result = calendar.date(byAdding: .day, value: 1, to: result)!
            if !calendar.isDateInWeekend(result) {
                remaining -= 1
            }
        }
        return result
    }

    /// Whole workdays elapsed from `start` to `end` (weekends excluded). Counts each weekday
    /// strictly after `start`'s day, up to and including `end`'s day. Returns 0 if `end <= start`.
    public static func workdaysElapsed(from start: Date, to end: Date, calendar: Calendar) -> Int {
        guard end > start else { return 0 }
        var count = 0
        var cursor = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)
        while cursor < endDay {
            cursor = calendar.date(byAdding: .day, value: 1, to: cursor)!
            if !calendar.isDateInWeekend(cursor) {
                count += 1
            }
        }
        return count
    }
}
