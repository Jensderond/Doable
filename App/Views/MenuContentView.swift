import SwiftUI
import SwiftData
import DoableCore

struct MenuContentView: View {
    @Bindable var store: TodoStore
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<TodoItem> { $0.isDone == false }) private var rawItems: [TodoItem]

    @State private var newTitle = ""
    @FocusState private var inputFocused: Bool

    private var sortedItems: [TodoItem] { Ordering.activeSorted(rawItems) }

    var body: some View {
        VStack(spacing: 0) {
            TextField("Add a todo…", text: $newTitle)
                .textFieldStyle(.plain)
                .font(.body)
                .padding(10)
                .focused($inputFocused)
                .onSubmit(addItem)

            Divider()

            if sortedItems.isEmpty {
                Text("No todos")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 16)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(sortedItems) { item in
                            Text(item.title)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .frame(maxHeight: 320)
            }
        }
        .frame(width: 320)
        .onAppear { inputFocused = true }
    }

    private func addItem() {
        store.create(title: newTitle, in: context)
        newTitle = ""
        inputFocused = true
    }
}
