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

    func listListeningPorts() async throws -> [PortInfo] {
        let result: (stdout: String, stderr: String, exitCode: Int32)
        do {
            result = try runner("/usr/sbin/lsof", ["-nP", "-iTCP", "-sTCP:LISTEN", "-F", "pcnLP"], 5)
        } catch ProcessRunnerError.timeout {
            throw PortServiceError.lsofTimeout
        } catch {
            throw PortServiceError.lsofNotFound
        }

        let entries = Self.parseLsofOutput(result.stdout)
        let deduped = Self.dedupeEntries(entries)

        var commandMap: [Int32: String] = [:]
        for pid in Set(deduped.map(\.pid)) {
            if let r = try? runner("/bin/ps", ["-p", "\(pid)", "-o", "command="], 5),
               r.exitCode == 0 {
                let cmd = r.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
                if !cmd.isEmpty { commandMap[pid] = cmd }
            }
        }

        let currentUser = ProcessInfo.processInfo.userName

        return deduped
            .map { entry in
                PortInfo(
                    id: "\(entry.pid):\(entry.port)",
                    port: entry.port,
                    pid: entry.pid,
                    processName: entry.processName,
                    command: commandMap[entry.pid] ?? entry.processName,
                    user: entry.user,
                    isOwnedByCurrentUser: entry.user == currentUser
                )
            }
            .sorted { $0.port < $1.port }
    }

    func kill(pid: Int32, force: Bool) throws {
        let signal: Int32 = force ? SIGKILL : SIGTERM
        let result = Darwin.kill(pid, signal)
        if result == -1 {
            if errno == EPERM {
                throw PortServiceError.permissionDenied(pid: pid)
            }
        }
    }

    func isProcessAlive(pid: Int32) -> Bool {
        Darwin.kill(pid, 0) == 0
    }
}
