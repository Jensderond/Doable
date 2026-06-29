import SwiftUI
import SwiftData
import AppKit
import DoableCore

struct MenuContentView: View {
    @Bindable var store: TodoStore
    @Environment(\.modelContext) private var context
    @Environment(\.openSettings) private var openSettings
    @Query(filter: #Predicate<TodoItem> { $0.isDone == false }) private var rawItems: [TodoItem]

    @State private var newTitle = ""
    @FocusState private var inputFocused: Bool
    @State private var screen: Screen = .list
    private enum Screen { case list, archive }

    @State private var editingItemID: UUID?

    /// The id of the row currently highlighted as a drop target (for an insertion indicator).
    @State private var dropTargetID: UUID?

    private var sortedItems: [TodoItem] { Ordering.activeSorted(rawItems) }

    /// Measured height of the list's content, used to size the popover to its content up to a cap.
    @State private var listContentHeight: CGFloat = 0
    private let maxListHeight: CGFloat = 320

    var body: some View {
        Group {
            switch screen {
            case .list:
                listScreen
            case .archive:
                ArchiveView(store: store, onBack: { screen = .list })
            }
        }
        .onDisappear {
            store.commitPendingDone(in: context)
            editingItemID = nil
            screen = .list
        }
        .onChange(of: screen) { _, _ in editingItemID = nil }
        .background {
            Button("") {
                NSApp.activate(ignoringOtherApps: true)
                openSettings()
            }
            .keyboardShortcut(",", modifiers: .command)
            .opacity(0)
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
        }
    }

    private var listScreen: some View {
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
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(sortedItems) { item in
                            TodoRowView(store: store, item: item, editingItemID: $editingItemID)
                                .overlay(alignment: .top) {
                                    if dropTargetID == item.id {
                                        Rectangle()
                                            .fill(Color.accentColor)
                                            .frame(height: 2)
                                    }
                                }
                                .dropDestination(for: String.self) { ids, _ in
                                    handleDrop(ids, onto: item)
                                } isTargeted: { targeted in
                                    dropTargetID = targeted ? item.id : (dropTargetID == item.id ? nil : dropTargetID)
                                }
                        }
                        // Trailing zone so an item can be dropped at the very bottom.
                        Color.clear
                            .frame(height: 8)
                            .contentShape(Rectangle())
                            .dropDestination(for: String.self) { ids, _ in
                                handleDrop(ids, onto: nil)
                            }
                    }
                    .background(GeometryReader { proxy in
                        Color.clear.preference(key: ListHeightKey.self, value: proxy.size.height)
                    })
                }
                .frame(height: min(listContentHeight, maxListHeight))
                .onPreferenceChange(ListHeightKey.self) { listContentHeight = $0 }
                .scrollIndicators(.visible)
                .overlay(alignment: .bottom) {
                    if listContentHeight > maxListHeight {
                        LinearGradient(colors: [.black.opacity(0), .black.opacity(0.08)],
                                       startPoint: .top, endPoint: .bottom)
                            .frame(height: 18)
                            .allowsHitTesting(false)
                    }
                }
            }

            Divider()

            HStack {
                Button { screen = .archive } label: {
                    Label("Completed", systemImage: "archivebox")
                }
                .buttonStyle(.plain)
                Spacer()
                Button {
                    NSApp.activate(ignoringOtherApps: true)
                    openSettings()
                } label: {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.plain)
            }
            .padding(10)
        }
        .frame(width: 320)
        .onAppear { inputFocused = true }
    }

    private func addItem() {
        store.create(title: newTitle, in: context)
        newTitle = ""
        inputFocused = true
    }

    /// Translates a dropped item id into a `(from, to)` move. Dropping onto `target` inserts the
    /// dragged item immediately above `target`; a `nil` target drops it at the bottom. `to` is the
    /// post-removal insertion index that `TodoStore.move` expects.
    @discardableResult
    private func handleDrop(_ ids: [String], onto target: TodoItem?) -> Bool {
        dropTargetID = nil
        guard let draggedID = ids.first.flatMap({ UUID(uuidString: $0) }),
              let from = sortedItems.firstIndex(where: { $0.id == draggedID }),
              draggedID != target?.id
        else { return false }

        let reduced = sortedItems.filter { $0.id != draggedID }
        let to: Int
        if let target, let idx = reduced.firstIndex(where: { $0.id == target.id }) {
            to = idx
        } else {
            to = reduced.count // dropped on the trailing zone → bottom
        }
        store.move(from: from, to: to, in: context)
        return true
    }
}

/// Reports the intrinsic height of the todo list's content so the popover can size to it.
private struct ListHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
