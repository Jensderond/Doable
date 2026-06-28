import SwiftUI
import AppKit
import DoableCore

/// Content of the native Settings window (opened via the standard `Settings` scene).
struct SettingsView: View {
    @AppStorage("dueSoonWindow") private var windowRaw = DueSoonWindow.todayOnly.rawValue
    @AppStorage("staleThresholdWorkdays") private var staleThreshold = 3
    @State private var launchAtLogin = LoginItemManager.isEnabled
    @State private var installMessage: String?

    private var realHome: URL {
        guard let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir else {
            return FileManager.default.homeDirectoryForCurrentUser
        }
        return URL(fileURLWithPath: String(cString: dir))
    }

    private var binDir: URL { realHome.appendingPathComponent(".local/bin") }
    private var linkURL: URL { binDir.appendingPathComponent("doable") }
    private var bundledTool: URL {
        Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/doable")
    }

    private func installCLI() {
        let fm = FileManager.default
        do {
            try fm.createDirectory(at: binDir, withIntermediateDirectories: true)
            if fm.fileExists(atPath: linkURL.path) || (try? linkURL.checkResourceIsReachable()) == true {
                try? fm.removeItem(at: linkURL)
            }
            try fm.createSymbolicLink(at: linkURL, withDestinationURL: bundledTool)
            let path = ProcessInfo.processInfo.environment["PATH"] ?? ""
            if PathCheck.isOnPath(dir: binDir.path, path: path) {
                installMessage = "Installed: doable is ready to use."
            } else {
                installMessage = "Installed to \(linkURL.path).\nAdd to ~/.zshrc:\nexport PATH=\"$HOME/.local/bin:$PATH\""
            }
        } catch {
            installMessage = "Could not install automatically (\(error.localizedDescription)). "
                + "Run in Terminal:\nln -sf \"\(bundledTool.path)\" \"\(linkURL.path)\""
        }
    }

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

            Section("Command-line tool") {
                Button("Install \u{201C}doable\u{201D} command") { installCLI() }
                if let installMessage {
                    Text(installMessage)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 380, height: 320)
    }
}
