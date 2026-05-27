import XCTest
@testable import Portzilla

final class PortServiceTests: XCTestCase {

    func testListListeningPortsReturnsParsedPorts() async throws {
        let lsofOutput = [
            "p47291", "cnode", "Lpriscilla",
            "f24", "PTCP", "n*:3000",
            "f25", "PTCP", "n127.0.0.1:8081"
        ].joined(separator: "\n")

        let service = PortService { path, args, _ in
            if path == "/usr/sbin/lsof" {
                return (stdout: lsofOutput, stderr: "", exitCode: 0)
            }
            if path == "/bin/ps" {
                return (stdout: "next dev\n", stderr: "", exitCode: 0)
            }
            return (stdout: "", stderr: "", exitCode: 1)
        }

        let ports = try await service.listListeningPorts()
        XCTAssertEqual(ports.count, 2)
        XCTAssertEqual(ports[0].port, 3000)
        XCTAssertEqual(ports[1].port, 8081)
        XCTAssertEqual(ports[0].command, "next dev")
    }

    func testSortOrderAscendingByPort() async throws {
        let lsofOutput = [
            "p100", "cnode", "Luser", "f1", "PTCP", "n*:8081",
            "p200", "cpython", "Luser", "f1", "PTCP", "n*:3000"
        ].joined(separator: "\n")

        let service = PortService { path, _, _ in
            if path == "/usr/sbin/lsof" { return (stdout: lsofOutput, stderr: "", exitCode: 0) }
            return (stdout: "cmd\n", stderr: "", exitCode: 0)
        }

        let ports = try await service.listListeningPorts()
        XCTAssertEqual(ports[0].port, 3000)
        XCTAssertEqual(ports[1].port, 8081)
    }

    func testDeduplicationBySamePidAndPort() async throws {
        let lsofOutput = [
            "p100", "cnode", "Luser",
            "f1", "PTCP", "n*:3000",
            "f2", "PTCP", "n127.0.0.1:3000"
        ].joined(separator: "\n")

        let service = PortService { path, _, _ in
            if path == "/usr/sbin/lsof" { return (stdout: lsofOutput, stderr: "", exitCode: 0) }
            return (stdout: "node\n", stderr: "", exitCode: 0)
        }

        let ports = try await service.listListeningPorts()
        XCTAssertEqual(ports.count, 1)
    }

    func testIsOwnedByCurrentUserSetCorrectly() async throws {
        let currentUser = ProcessInfo.processInfo.userName
        let lsofOutput = [
            "p100", "cnode", "L\(currentUser)", "f1", "PTCP", "n*:3000",
            "p200", "cpostgres", "Lpostgres", "f1", "PTCP", "n*:5432"
        ].joined(separator: "\n")

        let service = PortService { path, _, _ in
            if path == "/usr/sbin/lsof" { return (stdout: lsofOutput, stderr: "", exitCode: 0) }
            return (stdout: "cmd\n", stderr: "", exitCode: 0)
        }

        let ports = try await service.listListeningPorts()
        let ownedPort = ports.first { $0.port == 3000 }!
        let otherPort = ports.first { $0.port == 5432 }!
        XCTAssertTrue(ownedPort.isOwnedByCurrentUser)
        XCTAssertFalse(otherPort.isOwnedByCurrentUser)
    }

    func testPsFailureFallsBackToLsofName() async throws {
        let lsofOutput = "p100\ncnode\nLuser\nf1\nPTCP\nn*:3000\n"

        let service = PortService { path, _, _ in
            if path == "/usr/sbin/lsof" { return (stdout: lsofOutput, stderr: "", exitCode: 0) }
            if path == "/bin/ps" { return (stdout: "", stderr: "error", exitCode: 1) }
            return (stdout: "", stderr: "", exitCode: 1)
        }

        let ports = try await service.listListeningPorts()
        XCTAssertEqual(ports[0].command, "node")
    }
}
