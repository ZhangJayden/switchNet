import AppKit
import SwiftUI

@MainActor
final class ProfileWindowController {
    private var window: NSWindow?
    private let appState: AppState

    init(appState: AppState) {
        self.appState = appState
    }

    func showWindow() {
        if window == nil {
            let rootView = ProfilesView(appState: appState)
            let hostingController = NSHostingController(rootView: rootView)
            let window = NSWindow(contentViewController: hostingController)
            window.title = "SwitchNet Profiles"
            window.setContentSize(NSSize(width: 720, height: 460))
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }

        NSApplication.shared.activate()
        window?.makeKeyAndOrderFront(nil)
    }
}
