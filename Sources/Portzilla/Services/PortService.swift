import Foundation
import Darwin

enum PortServiceError: Error, LocalizedError {
    case permissionDenied(pid: Int32)
    case lsofNotFound
    case lsofTimeout

    var errorDescription: String? {
        switch self {
        case .permissionDenied(let pid): return "Permission denied for PID \(pid)"
        case .lsofNotFound: return "lsof not available — Portzilla requires macOS system tools."
        case .lsofTimeout: return "Refresh timed out."
        }
    }
}

struct RawPortEntry {
    let pid: Int32
    let processName: String
    let user: String
    let port: Int
}

struct PortService: Sendable {
    typealias Runner = @Sendable (_ path: String, _ args: [String], _ timeout: TimeInterval) throws -> (stdout: String, stderr: String, exitCode: Int32)

    private let runner: Runner

    init(runner: @escaping Runner = { try ProcessRunner.run($0, args: $1, timeout: $2) }) {
        self.runner = runner
    }

    static func parseLsofOutput(_ output: String) -> [RawPortEntry] {
        var entries: [RawPortEntry] = []
        var currentPID: Int32?
        var currentName: String?
        var currentUser: String?

        for line in output.components(separatedBy: "\n") where !line.isEmpty {
            let prefix = line.first!
            let value = String(line.dropFirst())

            switch prefix {
            case "p":
                currentPID = Int32(value)
                currentName = nil
                currentUser = nil
            case "c":
                currentName = value
            case "L":
                currentUser = value
            case "n":
                guard let pid = currentPID,
                      let name = currentName,
                      let user = currentUser,
                      let port = parsePort(from: value) else { continue }
                entries.append(RawPortEntry(pid: pid, processName: name, user: user, port: port))
            default:
                break
            }
        }

        return entries
    }

    static func parsePort(from nameField: String) -> Int? {
        if nameField.contains("[") {
            guard let closeBracket = nameField.lastIndex(of: "]"),
                  nameField.index(after: closeBracket) < nameField.endIndex,
                  nameField[nameField.index(after: closeBracket)] == ":" else {
                return nil
            }
            let portStr = String(nameField[nameField.index(closeBracket, offsetBy: 2)...])
            return Int(portStr)
        }

        guard let lastColon = nameField.lastIndex(of: ":") else { return nil }
        let portStr = String(nameField[nameField.index(after: lastColon)...])
        return Int(portStr)
    }

    static func dedupeEntries(_ entries: [RawPortEntry]) -> [RawPortEntry] {
        var seen = Set<String>()
        return entries.filter { entry in
            let key = "\(entry.pid):\(entry.port)"
            return seen.insert(key).inserted
        }
    }
}
