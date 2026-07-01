import SwiftUI
import SwiftData
import DoableCore

/// In-window editor for a todo's due date: preset chips above a mini month
/// calendar, plus an opt-in type-to-set field. Deadlines are day-only; every
/// choice applies immediately and closes the panel. Rendered inline beneath
/// the edited row by `TodoRowView`.
struct DeadlineEditor: View {
    @Bindable var store: TodoStore
    let item: TodoItem
    @Environment(\.modelContext) private var context
    let onDismiss: () -> Void

    @AppStorage("typeToSetDeadline") private var typeToSet = false
    @State private var displayedMonth: Date
    @State private var query = ""
    @FocusState private var queryFocused: Bool

    private let calendar = Calendar.current

    init(store: TodoStore, item: TodoItem, onDismiss: @escaping () -> Void) {
        self.store = store
        self.item = item
        self.onDismiss = onDismiss
        self._displayedMonth = State(initialValue: item.dueDate ?? Date())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if typeToSet { typeField }
            presetChips
            calendarGrid
            if item.dueDate != nil {
                Button("Clear deadline", role: .destructive) { apply(nil) }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Type-to-set field

    private var currentMatch: DeadlineInputParser.Match? {
        DeadlineInputParser.match(query, now: Date(), calendar: calendar)
    }

    private var typeField: some View {
        HStack(spacing: 6) {
            TextField("Type a day… (fri, tomorrow)", text: $query)
                .textFieldStyle(.plain)
                .font(.callout)
                .focused($queryFocused)
                .onSubmit {
                    guard let match = currentMatch else { return }
                    apply(match.day)
                }
                .onExitCommand {
                    if query.isEmpty { onDismiss() } else { query = "" }
                }
            if let match = currentMatch {
                Text("\(match.label) → \(match.day, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day())")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .onAppear { queryFocused = true }
    }

    // MARK: - Preset chips

    private var presetChips: some View {
        HStack(spacing: 6) {
            ForEach(DuePreset.available(on: Date(), calendar: calendar), id: \.rawValue) { preset in
                Button(preset.displayName) {
                    apply(preset.date(from: Date(), calendar: calendar))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }

    // MARK: - Calendar

    private var calendarGrid: some View {
        VStack(spacing: 2) {
            monthHeader
            weekdayHeader
            ForEach(Array(MonthGrid.weeks(containing: displayedMonth, calendar: calendar).enumerated()),
                    id: \.offset) { _, week in
                HStack(spacing: 0) {
                    ForEach(Array(week.enumerated()), id: \.offset) { _, day in
                        dayCell(day)
                    }
                }
            }
        }
    }

    private var monthHeader: some View {
        HStack {
            Text(displayedMonth, format: .dateTime.month(.wide).year())
                .font(.subheadline.weight(.semibold))
            Spacer()
            Button { stepMonth(-1) } label: { Image(systemName: "chevron.left") }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            Button { stepMonth(1) } label: { Image(systemName: "chevron.right") }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .padding(.leading, 8)
        }
        .padding(.bottom, 4)
    }

    // Weekday symbols can repeat ("T", "T", "S", "S"), so identify columns by
    // offset, not by the symbol string.
    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(Array(MonthGrid.weekdaySymbols(calendar: calendar).enumerated()),
                    id: \.offset) { _, symbol in
                Text(symbol)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    @ViewBuilder
    private func dayCell(_ day: Date?) -> some View {
        if let day {
            let isSelected = item.dueDate.map { calendar.isDate($0, inSameDayAs: day) } ?? false
            let isPast = day < calendar.startOfDay(for: Date())
            Button {
                apply(DuePreset.dueTime(on: day, calendar: calendar))
            } label: {
                Text("\(calendar.component(.day, from: day))")
                    .font(.callout)
                    .frame(width: 26, height: 26)
                    .background {
                        if isSelected {
                            Circle().fill(Color.accentColor)
                        } else if calendar.isDateInToday(day) {
                            Circle().strokeBorder(Color.accentColor, lineWidth: 1)
                        }
                    }
                    .foregroundStyle(isSelected ? Color.white
                                     : isPast ? Color.secondary.opacity(0.5)
                                     : Color.primary)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isPast)
        } else {
            Color.clear.frame(height: 26).frame(maxWidth: .infinity)
        }
    }

    // MARK: - Actions

    private func stepMonth(_ months: Int) {
        displayedMonth = calendar.date(byAdding: .month, value: months, to: displayedMonth)!
    }

    /// Applies the deadline (or clears it, for `nil`) and closes the panel.
    private func apply(_ date: Date?) {
        store.setDueDate(date, for: item, in: context)
        onDismiss()
    }
}
