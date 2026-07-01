import Foundation

/// Quick due-date choices offered in the deadline editor. All resolve to the
/// target day at 17:00 in the supplied calendar's time zone. Tailored for a
/// work app: weekend choices are omitted and `tomorrow` is only offered when
/// tomorrow is a workday.
public enum DuePreset: String, CaseIterable, Sendable {
    case today
    case tomorrow
    case nextWeek

    public var displayName: String {
        switch self {
        case .today: return "Today"
        case .tomorrow: return "Tomorrow"
        case .nextWeek: return "Next week"
        }
    }

    /// The presets to display, relative to `now`. `tomorrow` is dropped when
    /// tomorrow falls on a weekend (i.e. on Friday, Saturday, and Sunday).
    public static func available(on now: Date, calendar: Calendar) -> [DuePreset] {
        allCases.filter { preset in
            guard preset == .tomorrow else { return true }
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: now)!
            return !calendar.isDateInWeekend(tomorrow)
        }
    }

    /// `day` at the canonical due time (17:00) in `calendar`'s time zone. All
    /// deadlines in the app store this time-of-day, even though the UI is day-only.
    public static func dueTime(on day: Date, calendar: Calendar) -> Date {
        calendar.date(bySettingHour: 17, minute: 0, second: 0, of: day)!
    }

    /// The due date this preset resolves to, relative to `now`.
    public func date(from now: Date, calendar: Calendar) -> Date {
        let monday = 2     // Gregorian weekday number
        let day: Date
        switch self {
        case .today:
            day = now
        case .tomorrow:
            day = calendar.date(byAdding: .day, value: 1, to: now)!
        case .nextWeek:
            let wd = calendar.component(.weekday, from: now)
            var add = (monday - wd + 7) % 7
            if add == 0 { add = 7 }
            day = calendar.date(byAdding: .day, value: add, to: now)!
        }
        return Self.dueTime(on: day, calendar: calendar)
    }
}
