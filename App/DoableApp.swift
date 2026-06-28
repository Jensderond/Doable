import SwiftUI
import SwiftData

@main
struct DoableApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var store = TodoStore()

    var body: some Scene {
        MenuBarExtra {
            MenuContentView(store: store)
        } label: {
            MenuBarLabel()
                .modelContainer(SharedContainer.shared)
        }
        .menuBarExtraStyle(.window)
        .modelContainer(SharedContainer.shared)

        Settings {
            SettingsView()
        }
    }
}
