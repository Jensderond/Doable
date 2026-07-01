import Foundation

/// Pure month-layout math for the deadline editor's mini calendar: the weeks
/// of a month as rows of 7 optional days, honoring the calendar's first weekday.
public enum MonthGrid {
    /// The weeks of `date`'s month. Each row has exactly 7 cells; `nil` pads
    /// before the 1st and after the last day. Non-nil cells are start-of-day dates.
    public static func weeks(containing date: Date, calendar: Calendar) -> [[Date?]] {
        let comps = calendar.dateComponents([.year, .month], from: date)
        let firstOfMonth = calendar.date(from: comps)!
        let dayCount = calendar.range(of: .day, in: .month, for: firstOfMonth)!.count
        let leading = (calendar.component(.weekday, from: firstOfMonth) - calendar.firstWeekday + 7) % 7

        var cells: [Date?] = Array(repeating: nil, count: leading)
        for offset in 0..<dayCount {
            cells.append(calendar.date(byAdding: .day, value: offset, to: firstOfMonth)!)
        }
        while cells.count % 7 != 0 { cells.append(nil) }
        return stride(from: 0, to: cells.count, by: 7).map { Array(cells[$0..<($0 + 7)]) }
    }

    /// Very-short weekday symbols ("S", "M", …) rotated so index 0 is
    /// `calendar.firstWeekday`, matching the column order of `weeks`.
    public static func weekdaySymbols(calendar: Calendar) -> [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let shift = calendar.firstWeekday - 1
        return Array(symbols[shift...] + symbols[..<shift])
    }
}
