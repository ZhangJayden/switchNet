import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var appState: AppState!
    private var statusBarController: StatusBarController!
    private var profileWindowController: ProfileWindowController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        appState = AppState(
            profileStore: ProfileStore(),
            networkManager: NetworkManager(shell: ShellRunner()),
            launchAtLoginManager: LaunchAtLoginManager()
        )
        profileWindowController = ProfileWindowController(appState: appState)
        statusBarController = StatusBarController(
            appState: appState,
            profileWindowController: profileWindowController
        )
        appState.refresh()
    }

    func applicationWillTerminate(_ notification: Notification) {
        appState.saveProfiles()
    }
}
