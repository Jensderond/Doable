import SwiftUI

@main
struct DoableApp: App {
    var body: some Scene {
        MenuBarExtra {
            MenuContentView()
        } label: {
            MenuBarLabel()
        }
        .menuBarExtraStyle(.window)
    }
}
