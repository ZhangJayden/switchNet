import Foundation

@MainActor
final class AppState: ObservableObject {
    @Published var profiles: [NetworkProfile]
    @Published var snapshot: NetworkSnapshot = .empty
    @Published var message: String?
    @Published var isApplying = false

    private let profileStore: ProfileStore
    private let networkManager: NetworkManager
    private let launchAtLoginManager: LaunchAtLoginManager

    init(
        profileStore: ProfileStore,
        networkManager: NetworkManager,
        launchAtLoginManager: LaunchAtLoginManager
    ) {
        self.profileStore = profileStore
        self.networkManager = networkManager
        self.launchAtLoginManager = launchAtLoginManager
        self.profiles = profileStore.load()
    }

    var launchAtLoginEnabled: Bool {
        launchAtLoginManager.isEnabled
    }

    func refresh() {
        do {
            snapshot = try networkManager.currentSnapshot()
            message = nil
        } catch {
            message = error.localizedDescription
        }
    }

    func applyDHCP() {
        apply {
            try networkManager.applyDHCP(serviceName: snapshot.serviceName)
        }
    }

    func applyProfile(id: UUID) {
        guard let profile = profiles.first(where: { $0.id == id }) else { return }

        apply {
            try networkManager.apply(profile: profile, serviceName: snapshot.serviceName)
        }
    }

    func addProfile() {
        profiles.append(
            NetworkProfile(
                name: "Home Static",
                ipAddress: "192.168.1.88",
                subnetMask: "255.255.255.0",
                router: "192.168.1.1",
                dnsServers: ["223.5.5.5", "8.8.8.8"],
                boundSSID: snapshot.ssid == "Unknown" ? "" : snapshot.ssid
            )
        )
        saveProfiles()
    }

    func deleteProfile(id: UUID) {
        profiles.removeAll { $0.id == id }
        saveProfiles()
    }

    func saveProfiles() {
        do {
            try profileStore.save(profiles)
            message = "Profiles saved."
        } catch {
            message = error.localizedDescription
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try launchAtLoginManager.setEnabled(enabled)
            objectWillChange.send()
        } catch {
            message = error.localizedDescription
        }
    }

    private func apply(_ operation: () throws -> Void) {
        isApplying = true
        defer { isApplying = false }

        do {
            try operation()
            refresh()
            message = "Network settings updated."
        } catch {
            message = error.localizedDescription
        }
    }
}
