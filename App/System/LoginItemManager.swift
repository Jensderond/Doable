import Foundation
import ServiceManagement

/// Thin wrapper over SMAppService for registering the app as a login item.
enum LoginItemManager {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Registers or unregisters the app as a login item. Returns the resulting enabled state.
    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Login item update failed: \(error)")
        }
        return isEnabled
    }
}
