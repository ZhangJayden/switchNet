import Foundation

struct ProfileStore {
    private var fileURL: URL {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return baseURL
            .appendingPathComponent("SwitchNet", isDirectory: true)
            .appendingPathComponent("profiles.json")
    }

    func load() -> [NetworkProfile] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return [
                NetworkProfile(
                    name: "Office Static",
                    ipAddress: "192.168.1.88",
                    subnetMask: "255.255.255.0",
                    router: "192.168.1.1",
                    dnsServers: ["223.5.5.5", "8.8.8.8"]
                )
            ]
        }

        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode([NetworkProfile].self, from: data)
        } catch {
            return []
        }
    }

    func save(_ profiles: [NetworkProfile]) throws {
        let directoryURL = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let data = try JSONEncoder.prettyPrinted.encode(profiles)
        try data.write(to: fileURL, options: .atomic)
    }
}

private extension JSONEncoder {
    static var prettyPrinted: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
