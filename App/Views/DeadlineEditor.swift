import SwiftUI
import SwiftData

struct DeadlineEditor: View {
    @Bindable var store: TodoStore
    let item: TodoItem
    @Environment(\.modelContext) private var context
    @Binding var isPresented: Bool

    @State private var date: Date

    init(store: TodoStore, item: TodoItem, isPresented: Binding<Bool>) {
        self.store = store
        self.item = item
        self._isPresented = isPresented
        self._date = State(initialValue: item.dueDate ?? Date())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            DatePicker("Due", selection: $date, displayedComponents: [.date, .hourAndMinute])
                .datePickerStyle(.compact)
                .labelsHidden()

            HStack {
                if item.dueDate != nil {
                    Button("Clear") {
                        store.setDueDate(nil, for: item, in: context)
                        isPresented = false
                    }
                }
                Spacer()
                Button("Done") {
                    store.setDueDate(date, for: item, in: context)
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 240)
    }
}
