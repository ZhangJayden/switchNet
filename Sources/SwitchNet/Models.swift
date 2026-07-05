import Foundation

struct NetworkProfile: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var ipAddress: String
    var subnetMask: String
    var router: String
    var dnsServers: [String]
    var boundSSID: String

    init(
        id: UUID = UUID(),
        name: String,
        ipAddress: String,
        subnetMask: String,
        router: String,
        dnsServers: [String],
        boundSSID: String = ""
    ) {
        self.id = id
        self.name = name
        self.ipAddress = ipAddress
        self.subnetMask = subnetMask
        self.router = router
        self.dnsServers = dnsServers
        self.boundSSID = boundSSID
    }
}

struct NetworkSnapshot: Equatable {
    var serviceName: String
    var deviceName: String
    var ssid: String
    var ipAddress: String
    var subnetMask: String
    var router: String
    var dnsServers: [String]
    var isDHCP: Bool

    static let empty = NetworkSnapshot(
        serviceName: "Wi-Fi",
        deviceName: "",
        ssid: "Unknown",
        ipAddress: "-",
        subnetMask: "-",
        router: "-",
        dnsServers: [],
        isDHCP: false
    )
}

enum SwitchNetError: LocalizedError {
    case wifiServiceNotFound
    case invalidProfile(String)
    case commandFailed(String)

    var errorDescription: String? {
        switch self {
        case .wifiServiceNotFound:
            "Could not find a Wi-Fi network service on this Mac."
        case .invalidProfile(let message):
            message
        case .commandFailed(let message):
            message
        }
    }
}
