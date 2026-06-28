import SwiftUI
import DoableCore

/// "Developer" settings pane: install the `doable` command-line tool onto PATH.
struct DeveloperSettingsView: View {
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
    }
}
