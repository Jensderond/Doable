import SwiftUI
import DoableCore

/// Content of the native Settings window (opened via the standard `Settings` scene).
struct SettingsView: View {
    @AppStorage("dueSoonWindow") private var windowRaw = DueSoonWindow.todayOnly.rawValue
    @AppStorage("staleThresholdWorkdays") private var staleThreshold = 3
    @State private var launchAtLogin = LoginItemManager.isEnabled

    var body: some View {
        Form {
            Toggle("Launch at login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, newValue in
                    launchAtLogin = LoginItemManager.setEnabled(newValue)
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
        .frame(width: 380, height: 240)
    }
}
