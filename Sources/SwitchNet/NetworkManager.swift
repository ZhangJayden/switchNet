import Foundation

struct NetworkManager {
    private let shell: ShellRunner
    private let networksetup = "/usr/sbin/networksetup"

    init(shell: ShellRunner) {
        self.shell = shell
    }

    func currentSnapshot() throws -> NetworkSnapshot {
        let service = try detectWiFiService()
        let info = try shell.run(networksetup, arguments: ["-getinfo", service.name])
        let dnsOutput = try shell.run(networksetup, arguments: ["-getdnsservers", service.name])
        let ssid = currentSSID(deviceName: service.deviceName)

        return NetworkSnapshot(
            serviceName: service.name,
            deviceName: service.deviceName,
            ssid: ssid,
            ipAddress: parseInfoValue("IP address", from: info) ?? "-",
            subnetMask: parseInfoValue("Subnet mask", from: info) ?? "-",
            router: parseInfoValue("Router", from: info) ?? "-",
            dnsServers: parseDNSServers(dnsOutput),
            isDHCP: info.localizedCaseInsensitiveContains("DHCP Configuration")
        )
    }

    func applyDHCP(serviceName: String) throws {
        _ = try shell.run(networksetup, arguments: ["-setdhcp", serviceName], requiresAdmin: true)
        _ = try shell.run(networksetup, arguments: ["-setdnsservers", serviceName, "Empty"], requiresAdmin: true)
    }

    func apply(profile: NetworkProfile, serviceName: String) throws {
        try validate(profile)
        _ = try shell.run(
            networksetup,
            arguments: [
                "-setmanual",
                serviceName,
                profile.ipAddress,
                profile.subnetMask,
                profile.router
            ],
            requiresAdmin: true
        )

        if profile.dnsServers.isEmpty {
            _ = try shell.run(networksetup, arguments: ["-setdnsservers", serviceName, "Empty"], requiresAdmin: true)
        } else {
            _ = try shell.run(
                networksetup,
                arguments: ["-setdnsservers", serviceName] + profile.dnsServers,
                requiresAdmin: true
            )
        }
    }

    private func detectWiFiService() throws -> (name: String, deviceName: String) {
        let output = try shell.run(networksetup, arguments: ["-listallhardwareports"])
        var hardwarePort = ""

        for rawLine in output.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)

            if line.hasPrefix("Hardware Port:") {
                hardwarePort = line.replacingOccurrences(of: "Hardware Port:", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }

            if line.hasPrefix("Device:"),
               hardwarePort.localizedCaseInsensitiveContains("Wi-Fi")
                    || hardwarePort.localizedCaseInsensitiveContains("AirPort") {
                let deviceName = line.replacingOccurrences(of: "Device:", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return (hardwarePort, deviceName)
            }
        }

        throw SwitchNetError.wifiServiceNotFound
    }

    private func currentSSID(deviceName: String) -> String {
        guard !deviceName.isEmpty else { return "Unknown" }

        do {
            let output = try shell.run(networksetup, arguments: ["-getairportnetwork", deviceName])
            if output.localizedCaseInsensitiveContains("not associated") {
                return "Not connected"
            }

            if let range = output.range(of: ": ") {
                return String(output[range.upperBound...])
            }
        } catch {
            return "Unknown"
        }

        return "Unknown"
    }

    private func parseInfoValue(_ key: String, from output: String) -> String? {
        for rawLine in output.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            let prefix = "\(key):"
            if line.hasPrefix(prefix) {
                let value = line.replacingOccurrences(of: prefix, with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return value.isEmpty ? nil : value
            }
        }

        return nil
    }

    private func parseDNSServers(_ output: String) -> [String] {
        if output.localizedCaseInsensitiveContains("There aren't any DNS Servers") {
            return []
        }

        return output
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func validate(_ profile: NetworkProfile) throws {
        guard isIPv4(profile.ipAddress) else {
            throw SwitchNetError.invalidProfile("Invalid IP address: \(profile.ipAddress)")
        }

        guard isIPv4(profile.subnetMask) else {
            throw SwitchNetError.invalidProfile("Invalid subnet mask: \(profile.subnetMask)")
        }

        guard isIPv4(profile.router) else {
            throw SwitchNetError.invalidProfile("Invalid router: \(profile.router)")
        }

        for dnsServer in profile.dnsServers where !isIPv4(dnsServer) {
            throw SwitchNetError.invalidProfile("Invalid DNS server: \(dnsServer)")
        }
    }

    private func isIPv4(_ value: String) -> Bool {
        let parts = value.split(separator: ".")
        guard parts.count == 4 else { return false }

        return parts.allSatisfy { part in
            guard let octet = Int(part), octet >= 0, octet <= 255 else { return false }
            return String(octet) == part || part == "0"
        }
    }
}
