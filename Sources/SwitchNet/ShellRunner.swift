import Foundation

struct ShellRunner {
    func run(_ executable: String, arguments: [String], requiresAdmin: Bool = false) throws -> String {
        if requiresAdmin {
            return try runWithAdministratorPrivileges(executable, arguments: arguments)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let error = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

        guard process.terminationStatus == 0 else {
            throw SwitchNetError.commandFailed(error.isEmpty ? output : error)
        }

        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func runWithAdministratorPrivileges(_ executable: String, arguments: [String]) throws -> String {
        let command = ([executable] + arguments)
            .map(shellEscaped)
            .joined(separator: " ")
        let script = "do shell script \"\(appleScriptEscaped(command))\" with administrator privileges"
        return try run("/usr/bin/osascript", arguments: ["-e", script])
    }

    private func shellEscaped(_ value: String) -> String {
        guard !value.isEmpty else { return "''" }
        return "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private func appleScriptEscaped(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
