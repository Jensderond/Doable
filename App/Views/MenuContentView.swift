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

    /// The item currently being dragged. Its source row renders dimmed (a "ghost") and a floating
    /// ghost copy follows the cursor. `nil` when no drag is in progress.
    @State private var draggingItem: TodoItem?
    /// A working copy of the visible order, reordered live while dragging so rows shuffle to open a
    /// gap at the prospective drop position. The real order is only persisted on drop.
    @State private var order: [TodoItem] = []
    /// Each row's frame in the "list" coordinate space, used to map the cursor's Y to a drop index.
    @State private var rowFrames: [UUID: CGRect] = [:]
    /// The cursor's Y position (list space) during a drag, where the floating ghost is drawn.
    @State private var dragGhostY: CGFloat?

    private var sortedItems: [TodoItem] { Ordering.activeSorted(rawItems) }

    /// While dragging, show the live working order; otherwise the authoritative sorted list.
    private var displayItems: [TodoItem] {
        draggingItem == nil ? sortedItems : order
    }

    /// Whether the dragged item would become bookmarked if dropped now (it sits above the
    /// separator). Falls back to its current pin state when no boundary is shown.
    private var draggedWouldBePinned: Bool {
        guard let d = draggingItem else { return false }
        guard let s = separatorIndex,
              let idx = displayItems.firstIndex(where: { $0.id == d.id }) else { return d.isPinned }
        if idx == s { return d.isPinned }   // exact boundary (move's d == p) keeps current state
        return idx < s
    }

    /// Insertion index in `displayItems` for the pinned↔normal separator, or `nil` when none.
    private var separatorIndex: Int? {
        let flags = displayItems.map(\.isPinned)
        let dragIdx = draggingItem.flatMap { d in displayItems.firstIndex { $0.id == d.id } }
        return Reorder.separatorIndex(pinFlags: flags, dragging: dragIdx)
    }

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
            endDrag() // recover if the popover was dismissed mid-drag
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
                    ZStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(displayItems.enumerated()), id: \.element.id) { idx, item in
                                if idx == separatorIndex { bookmarkSeparator }
                                listRow(item)
                            }
                            if separatorIndex == displayItems.count { bookmarkSeparator }
                        }
                        .background(GeometryReader { proxy in
                            Color.clear.preference(key: ListHeightKey.self, value: proxy.size.height)
                        })

                        // Ghost copy of the dragged row, following the cursor so the drop point is clear.
                        if let dragging = draggingItem, let y = dragGhostY {
                            ghostRow(dragging)
                                .frame(width: 320)
                                .position(x: 160, y: y)
                                .allowsHitTesting(false)
                                .transition(.identity)
                        }
                    }
                    .coordinateSpace(name: "list")
                }
                .frame(height: min(listContentHeight, maxListHeight))
                .onPreferenceChange(ListHeightKey.self) { listContentHeight = $0 }
                .onPreferenceChange(RowFramesKey.self) { rowFrames = $0 }
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

    /// One list row, wired for gesture-based reordering. The dragged row dims; pending-done rows
    /// (showing "Undo") cannot be dragged. Each row reports its frame so the drag can find the
    /// drop index from the cursor position.
    @ViewBuilder
    private func listRow(_ item: TodoItem) -> some View {
        let row = TodoRowView(store: store, item: item, editingItemID: $editingItemID)
            .opacity(draggingItem?.id == item.id ? 0.3 : 1)
            .background(GeometryReader { proxy in
                Color.clear.preference(key: RowFramesKey.self,
                                       value: [item.id: proxy.frame(in: .named("list"))])
            })
        if store.pendingDone.contains(item.id) {
            row
        } else {
            row.gesture(dragGesture(for: item))
        }
    }

    /// A simplified, dimmed copy of a row, drawn at the cursor while dragging.
    private func ghostRow(_ item: TodoItem) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "circle").foregroundStyle(.secondary)
            Text(item.title)
                .fontWeight(draggedWouldBePinned ? .bold : .regular)
                .lineLimit(1)
            Spacer(minLength: 8)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 6))
        .opacity(0.9)
        .shadow(radius: 5)
    }

    /// A thin rule marking the bookmarked↔normal boundary. Subtle at rest; accent-colored and a
    /// touch heavier while dragging, so crossing it (which flips the pin state) is obvious.
    private var bookmarkSeparator: some View {
        let dragging = draggingItem != nil
        return Rectangle()
            .fill(dragging ? Color.accentColor.opacity(0.9) : Color.secondary.opacity(0.25))
            .frame(height: dragging ? 2 : 1)
            .padding(.horizontal, 10)
            .padding(.vertical, dragging ? 3 : 2)
            .allowsHitTesting(false)
    }

    /// Click-drag (>6 pt) reorders; a plain click stays under 6 pt so the row's buttons still tap.
    /// Works entirely in-view (no OS drag-and-drop), so it commits reliably inside the popover.
    private func dragGesture(for item: TodoItem) -> some Gesture {
        DragGesture(minimumDistance: 6, coordinateSpace: .named("list"))
            .onChanged { value in
                if draggingItem?.id != item.id {
                    draggingItem = item
                    order = sortedItems
                }
                dragGhostY = value.location.y
                reorder(toY: value.location.y)
            }
            .onEnded { _ in commitDrag() }
    }

    /// Moves the dragged item within `order` to the row whose midpoint the cursor has passed.
    private func reorder(toY y: CGFloat) {
        guard let dragging = draggingItem,
              let current = order.firstIndex(where: { $0.id == dragging.id }) else { return }
        let target = targetIndex(forY: y)
        guard target != current else { return }
        withAnimation(.easeInOut(duration: 0.15)) {
            let moved = order.remove(at: current)
            order.insert(moved, at: target)
        }
    }

    /// The index in `order` the cursor is over, by comparing against each row's vertical midpoint.
    private func targetIndex(forY y: CGFloat) -> Int {
        for (idx, item) in order.enumerated() {
            if let frame = rowFrames[item.id], y < frame.midY { return idx }
        }
        return max(0, order.count - 1)
    }

    private func addItem() {
        store.create(title: newTitle, in: context)
        newTitle = ""
        inputFocused = true
    }

    /// Persists the live-reordered position of the dragged item. `from` is its index in the
    /// authoritative pre-drag order; `to` is its index in the working `order` (which equals the
    /// post-removal insertion index `TodoStore.move` expects, since only this one item moved).
    /// No-op when the order is unchanged. Clears the drag state regardless.
    private func commitDrag() {
        guard let dragging = draggingItem else { return }
        defer { endDrag() }
        guard order.map(\.id) != sortedItems.map(\.id),
              let from = sortedItems.firstIndex(where: { $0.id == dragging.id }),
              let to = order.firstIndex(where: { $0.id == dragging.id })
        else { return }
        store.move(from: from, to: to, in: context)
    }

    private func endDrag() {
        draggingItem = nil
        dragGhostY = nil
    }
}

/// Reports each row's frame (in the "list" coordinate space) so a drag can map cursor Y → index.
private struct RowFramesKey: PreferenceKey {
    static let defaultValue: [UUID: CGRect] = [:]
    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

/// Reports the intrinsic height of the todo list's content so the popover can size to it.
private struct ListHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
