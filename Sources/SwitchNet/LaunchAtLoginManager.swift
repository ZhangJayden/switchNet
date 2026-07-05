import Foundation
import ServiceManagement

struct LaunchAtLoginManager {
    var isEnabled: Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }

        return false
    }

    func setEnabled(_ enabled: Bool) throws {
        guard #available(macOS 13.0, *) else {
            throw SwitchNetError.commandFailed("Launch at login requires macOS 13 or later.")
        }

        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
