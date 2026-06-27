import SwiftUI
import SwiftData
import DoableCore

/// In-window editor for a todo's due date: quick presets plus a custom picker.
/// Rendered by `MenuContentView` (overlay) or `TodoRowView` (inline) — never in a popover.
struct DeadlineEditor: View {
    @Bindable var store: TodoStore
    let item: TodoItem
    @Environment(\.modelContext) private var context
    let onDismiss: () -> Void

    @State private var date: Date

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    init(store: TodoStore, item: TodoItem, onDismiss: @escaping () -> Void) {
        self.store = store
        self.item = item
        self.onDismiss = onDismiss
        self._date = State(initialValue: item.dueDate ?? Date())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Set due date")
                .font(.headline)

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(DuePreset.allCases, id: \.rawValue) { preset in
                    Button(preset.displayName) { apply(preset) }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                }
            }

            Divider()

            HStack {
                Text("Custom")
                    .foregroundStyle(.secondary)
                Spacer()
                DatePicker("", selection: $date, displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.compact)
                    .labelsHidden()
            }

            Divider()

            HStack {
                if item.dueDate != nil {
                    Button("Clear", role: .destructive) {
                        store.setDueDate(nil, for: item, in: context)
                        onDismiss()
                    }
                }
                Spacer()
                Button("Done") {
                    store.setDueDate(date, for: item, in: context)
                    onDismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 260)
    }

    private func apply(_ preset: DuePreset) {
        store.setDueDate(preset.date(from: Date(), calendar: .current), for: item, in: context)
        onDismiss()
    }
}
