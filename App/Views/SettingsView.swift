import SwiftUI
import DoableCore

struct SettingsView: View {
    var onBack: () -> Void

    @AppStorage("dueSoonWindow") private var windowRaw = DueSoonWindow.todayOnly.rawValue
    @AppStorage("staleThresholdWorkdays") private var staleThreshold = 3
    @State private var launchAtLogin = LoginItemManager.isEnabled

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { onBack() } label: { Label("Back", systemImage: "chevron.left") }
                    .buttonStyle(.plain)
                Spacer()
                Text("Settings").font(.headline)
                Spacer()
                Label("Back", systemImage: "chevron.left").hidden()
            }
            .padding(10)

            Divider()

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
            .scrollContentBackground(.hidden)
        }
        .frame(width: 320)
    }
}
