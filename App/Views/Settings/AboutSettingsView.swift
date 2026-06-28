import SwiftUI
import AppKit

/// "About" settings pane: app identity, version, developer, and GitHub link.
struct AboutSettingsView: View {
    private static let repoURL = URL(string: "https://github.com/Jensderond/Doable")!

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }
    private var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)

            VStack(spacing: 4) {
                Text("Doable")
                    .font(.title2.bold())
                Text("Version \(version) (\(build))")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Text("by Jens de Rond · redkiwi")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            // Future: a "Check for Updates" button slots into this VStack here.
            Link("View on GitHub", destination: Self.repoURL)
                .font(.callout)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .textSelection(.enabled)
    }
}
