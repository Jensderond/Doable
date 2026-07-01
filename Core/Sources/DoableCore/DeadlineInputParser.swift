import Foundation

/// Parses the deadline editor's type-to-set input. English keywords only,
/// matched case-insensitively by prefix against a priority-ordered candidate
/// list: today, tomorrow, next week, then weekdays Monday→Sunday. A weekday
/// resolves to its next occurrence strictly after today ("fri" typed on a
/// Friday means next Friday — "today" already covers today).
public enum DeadlineInputParser {
    public struct Match: Equatable, Sendable {
        /// The full matched keyword, e.g. "friday" for input "f".
        public let label: String
        /// The resolved day at the canonical 17:00 due time.
        public let day: Date

        public init(label: String, day: Date) {
            self.label = label
            self.day = day
        }
    }

    /// Weekday keywords in priority (Monday-first) order, with their
    /// Gregorian weekday numbers (Sunday = 1).
    private static let weekdays: [(label: String, weekday: Int)] = [
        ("monday", 2), ("tuesday", 3), ("wednesday", 4), ("thursday", 5),
        ("friday", 6), ("saturday", 7), ("sunday", 1),
    ]

    public static func match(_ input: String, now: Date, calendar: Calendar) -> Match? {
        let query = input.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return nil }

        let presets: [(label: String, preset: DuePreset)] = [
            ("today", .today), ("tomorrow", .tomorrow), ("next week", .nextWeek),
        ]
        for (label, preset) in presets where label.hasPrefix(query) {
            return Match(label: label, day: preset.date(from: now, calendar: calendar))
        }
        for (label, weekday) in weekdays where label.hasPrefix(query) {
            return Match(label: label, day: next(weekday: weekday, after: now, calendar: calendar))
        }
        return nil
    }

    /// The next `weekday` strictly after `now`'s day, at 17:00.
    private static func next(weekday: Int, after now: Date, calendar: Calendar) -> Date {
        let current = calendar.component(.weekday, from: now)
        var add = (weekday - current + 7) % 7
        if add == 0 { add = 7 }
        let day = calendar.date(byAdding: .day, value: add, to: now)!
        return DuePreset.dueTime(on: day, calendar: calendar)
    }
}
