import SwiftUI
import SwiftData
import DoableCore

struct ArchiveView: View {
    var store: TodoStore
    var onBack: () -> Void
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<TodoItem> { $0.isDone == true },
           sort: \TodoItem.completedAt, order: .reverse) private var items: [TodoItem]
    @State private var filter: CompletedFilter = .thisWeek

    /// Measured height of the completed list's content, used to size the scroll area to its content
    /// up to a cap (a bare `maxHeight` ScrollView collapses inside the content-sizing popover).
    @State private var listContentHeight: CGFloat = 0
    private let maxListHeight: CGFloat = 320

    private var filteredItems: [TodoItem] {
        let range = filter.dateRange(now: Date(), calendar: .current)
        return items.filter { item in
            guard let completedAt = item.completedAt else { return false }
            return range.contains(completedAt)
        }
    }

    private var emptyMessage: String {
        switch filter {
        case .thisWeek: return "Nothing completed this week"
        case .lastWeek: return "Nothing completed last week"
        case .last30Days: return "Nothing completed in the last 30 days"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { onBack() } label: {
                    Label("Back", systemImage: "chevron.left")
                }
                .buttonStyle(.plain)
                Spacer()
                Text("Completed")
                    .font(.headline)
                Spacer()
                Picker("Range", selection: $filter) {
                    ForEach(CompletedFilter.allCases, id: \.self) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .fixedSize()
            }
            .padding(10)

            Divider()

            if filteredItems.isEmpty {
                Text(emptyMessage)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(filteredItems) { item in
                            HStack(spacing: 8) {
                                Button { store.restore(item, in: context) } label: {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                                .help("Mark as not done")
                                Text(item.title)
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                        }
                    }
                    .background(GeometryReader { proxy in
                        Color.clear.preference(key: ArchiveListHeightKey.self, value: proxy.size.height)
                    })
                }
                .frame(height: min(listContentHeight, maxListHeight))
                .onPreferenceChange(ArchiveListHeightKey.self) { listContentHeight = $0 }
            }
        }
        .frame(width: 320)
    }
}

/// Reports the intrinsic height of the completed list's content so the scroll area sizes to it.
private struct ArchiveListHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
