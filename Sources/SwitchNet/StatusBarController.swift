import AppKit
import Combine

@MainActor
final class StatusBarController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let appState: AppState
    private let profileWindowController: ProfileWindowController
    private var cancellable: AnyCancellable?

    init(appState: AppState, profileWindowController: ProfileWindowController) {
        self.appState = appState
        self.profileWindowController = profileWindowController
        super.init()
        configureStatusItem()
        cancellable = appState.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async {
                self?.rebuildMenu()
            }
        }
        rebuildMenu()
    }

    private func configureStatusItem() {
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "wifi.router", accessibilityDescription: "SwitchNet")
            button.imagePosition = .imageLeading
            button.title = "SwitchNet"
        }
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        menu.addItem(disabledItem("SSID: \(appState.snapshot.ssid)"))
        menu.addItem(disabledItem("Service: \(appState.snapshot.serviceName)"))
        menu.addItem(disabledItem("IP: \(appState.snapshot.ipAddress)"))
        menu.addItem(disabledItem("Gateway: \(appState.snapshot.router)"))
        menu.addItem(disabledItem("DNS: \(appState.snapshot.dnsServers.isEmpty ? "Automatic" : appState.snapshot.dnsServers.joined(separator: ", "))"))

        if let message = appState.message {
            menu.addItem(.separator())
            menu.addItem(disabledItem(message))
        }

        menu.addItem(.separator())

        let dhcpItem = NSMenuItem(title: "Use DHCP", action: #selector(useDHCP), keyEquivalent: "")
        dhcpItem.target = self
        dhcpItem.isEnabled = !appState.isApplying
        menu.addItem(dhcpItem)

        for profile in appState.profiles {
            let item = NSMenuItem(title: "Apply \(profile.name)", action: #selector(applyProfile(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = profile.id.uuidString
            item.isEnabled = !appState.isApplying
            menu.addItem(item)
        }

        menu.addItem(.separator())

        let manageItem = NSMenuItem(title: "Manage Profiles...", action: #selector(openProfiles), keyEquivalent: ",")
        manageItem.target = self
        menu.addItem(manageItem)

        let refreshItem = NSMenuItem(title: "Refresh Status", action: #selector(refresh), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)

        let launchItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchItem.target = self
        launchItem.state = appState.launchAtLoginEnabled ? .on : .off
        menu.addItem(launchItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit SwitchNet", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    private func disabledItem(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    @objc private func useDHCP() {
        appState.applyDHCP()
        rebuildMenu()
    }

    @objc private func applyProfile(_ sender: NSMenuItem) {
        guard
            let rawID = sender.representedObject as? String,
            let id = UUID(uuidString: rawID)
        else {
            return
        }

        appState.applyProfile(id: id)
        rebuildMenu()
    }

    @objc private func openProfiles() {
        profileWindowController.showWindow()
    }

    @objc private func refresh() {
        appState.refresh()
        rebuildMenu()
    }

    @objc private func toggleLaunchAtLogin() {
        appState.setLaunchAtLogin(!appState.launchAtLoginEnabled)
        rebuildMenu()
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
