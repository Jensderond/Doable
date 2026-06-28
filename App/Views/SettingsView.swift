import SwiftUI

/// Sidebar-based Settings window. General and Developer sit at the top of the
/// sidebar (a native `List`, for proper selection, padding and title-bar inset);
/// About is pinned to the bottom.
struct SettingsView: View {
    private enum Section: String, CaseIterable, Identifiable, Hashable {
        case general, developer, about
        var id: String { rawValue }
        var label: String {
            switch self {
            case .general: return "General"
            case .developer: return "Developer"
            case .about: return "About"
            }
        }
        var systemImage: String {
            switch self {
            case .general: return "gearshape"
            case .developer: return "hammer"
            case .about: return "info.circle"
            }
        }
    }

    @State private var selection: Section? = .general

    /// The effective selection (defaults to General if the list ever deselects).
    private var current: Section { selection ?? .general }

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                ForEach([Section.general, .developer]) { section in
                    Label(section.label, systemImage: section.systemImage)
                        .tag(section)
                }
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 215, max: 260)
            .toolbar(removing: .sidebarToggle)
            .safeAreaInset(edge: .bottom, spacing: 0) { aboutRow }
        } detail: {
            detail
                .navigationTitle(current.label)
        }
        .frame(minWidth: 640, idealWidth: 680, minHeight: 440, idealHeight: 480)
    }

    /// About row, pinned below the list. Styled to read as a selectable sidebar
    /// row since it lives outside the `List` (which can't pin an item to the bottom).
    private var aboutRow: some View {
        let isSelected = current == .about
        return VStack(spacing: 0) {
            Divider()
            Button {
                selection = .about
            } label: {
                Label(Section.about.label, systemImage: Section.about.systemImage)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.accentColor : Color.clear)
            )
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
    }

    @ViewBuilder private var detail: some View {
        switch current {
        case .general: GeneralSettingsView()
        case .developer: DeveloperSettingsView()
        case .about: AboutSettingsView()
        }
    }
}
