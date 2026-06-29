import SwiftUI
import DoableCore

/// "General" settings pane: launch-at-login, due-soon window, and stale threshold.
struct GeneralSettingsView: View {
    @AppStorage("dueSoonWindow") private var windowRaw = DueSoonWindow.todayOnly.rawValue
    @AppStorage("staleThresholdWorkdays") private var staleThreshold = 3
    @AppStorage("showUrgentInMenuBar") private var showUrgentInMenuBar = false
    @AppStorage("menuBarScope") private var scopeRaw = MenuBarScope.pinnedOnly.rawValue
    @State private var launchAtLogin = LoginItemManager.isEnabled

    var body: some View {
        Form {
            Toggle("Launch at login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, newValue in
                    launchAtLogin = LoginItemManager.setEnabled(newValue)
                }

            Toggle("Show task in menu bar", isOn: $showUrgentInMenuBar)

            if showUrgentInMenuBar {
                Picker("Show", selection: $scopeRaw) {
                    ForEach(MenuBarScope.allCases, id: \.rawValue) { scope in
                        Text(scope.displayName).tag(scope.rawValue)
                    }
                }
            }

            Picker("Due soon", selection: $windowRaw) {
                ForEach(DueSoonWindow.allCases, id: \.rawValue) { window in
                    Text(window.displayName).tag(window.rawValue)
                }
            }

            Stepper("Stale after \(staleThreshold) workday\(staleThreshold == 1 ? "" : "s")",
                    value: $staleThreshold, in: 1...30)
        }
        .formStyle(.grouped)
    }
}
