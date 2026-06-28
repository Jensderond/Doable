import SwiftUI

/// Sidebar-based Settings window. General and Developer sit at the top of the
/// sidebar; About is pinned to the bottom.
struct SettingsView: View {
    private enum Section: String, CaseIterable, Identifiable {
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

    @State private var selection: Section = .general

    var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 2) {
                sidebarRow(.general)
                sidebarRow(.developer)
                Spacer()
                sidebarRow(.about)
            }
            .padding(8)
            .navigationSplitViewColumnWidth(min: 170, ideal: 180, max: 220)
        } detail: {
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationTitle(selection.label)
        }
        .frame(minWidth: 620, idealWidth: 640, minHeight: 400, idealHeight: 420)
    }

    @ViewBuilder private var detail: some View {
        switch selection {
        case .general: GeneralSettingsView()
        case .developer: DeveloperSettingsView()
        case .about: AboutSettingsView()
        }
    }

    private func sidebarRow(_ section: Section) -> some View {
        Button {
            selection = section
        } label: {
            Label(section.label, systemImage: section.systemImage)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 5)
        .padding(.horizontal, 8)
        .background(
            selection == section ? Color.accentColor.opacity(0.15) : Color.clear,
            in: RoundedRectangle(cornerRadius: 6)
        )
    }
}
