import Foundation

/// Quick due-date choices offered in the deadline editor. All resolve to the
/// target day at 17:00 in the supplied calendar's time zone.
public enum DuePreset: String, CaseIterable, Sendable {
    case today
    case tomorrow
    case thisWeekend
    case nextWeek

    public var displayName: String {
        switch self {
        case .today: return "Today"
        case .tomorrow: return "Tomorrow"
        case .thisWeekend: return "This weekend"
        case .nextWeek: return "Next week"
        }
    }

    /// The due date this preset resolves to, relative to `now`.
    public func date(from now: Date, calendar: Calendar) -> Date {
        let dueHour = 17
        let saturday = 7   // Gregorian weekday number
        let monday = 2
        let day: Date
        switch self {
        case .today:
            day = now
        case .tomorrow:
            day = calendar.date(byAdding: .day, value: 1, to: now)!
        case .thisWeekend:
            if calendar.isDateInWeekend(now) {
                day = now
            } else {
                let wd = calendar.component(.weekday, from: now)
                day = calendar.date(byAdding: .day, value: saturday - wd, to: now)!
            }
        case .nextWeek:
            let wd = calendar.component(.weekday, from: now)
            var add = (monday - wd + 7) % 7
            if add == 0 { add = 7 }
            day = calendar.date(byAdding: .day, value: add, to: now)!
        }
        return calendar.date(bySettingHour: dueHour, minute: 0, second: 0, of: day)!
    }
}
