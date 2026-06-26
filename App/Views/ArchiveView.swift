import SwiftUI
import SwiftData

struct ArchiveView: View {
    var onBack: () -> Void
    @Query(filter: #Predicate<TodoItem> { $0.isDone == true },
           sort: \TodoItem.completedAt, order: .reverse) private var items: [TodoItem]

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
                // Symmetry spacer to keep the title centered.
                Label("Back", systemImage: "chevron.left").hidden()
            }
            .padding(10)

            Divider()

            if items.isEmpty {
                Text("Nothing archived yet")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(items) { item in
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.secondary)
                                Text(item.title)
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                        }
                    }
                }
                .frame(maxHeight: 320)
            }
        }
        .frame(width: 320)
    }
}
