import XCTest
@testable import Portzilla

final class LsofParserTests: XCTestCase {

    func testEmptyInput() {
        let result = PortService.parseLsofOutput("")
        XCTAssertTrue(result.isEmpty)
    }

    func testSingleProcessSinglePort() {
        let output = "p47291\ncnode\nLpriscilla\nf24\nPTCP\nn*:3000\n"
        let result = PortService.parseLsofOutput(output)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].pid, 47291)
        XCTAssertEqual(result[0].processName, "node")
        XCTAssertEqual(result[0].user, "priscilla")
        XCTAssertEqual(result[0].port, 3000)
    }

    func testSingleProcessMultiplePorts() {
        let output = [
            "p47291", "cnode", "Lpriscilla",
            "f24", "PTCP", "n*:3000",
            "f25", "PTCP", "n127.0.0.1:8081"
        ].joined(separator: "\n")
        let result = PortService.parseLsofOutput(output)
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].port, 3000)
        XCTAssertEqual(result[1].port, 8081)
        XCTAssertEqual(result[0].pid, result[1].pid)
    }

    func testIPv6Port() {
        let output = "p1234\ncpostgres\nLpostgres\nf5\nPTCP\nn[::1]:5432\n"
        let result = PortService.parseLsofOutput(output)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].port, 5432)
    }

    func testIPv6WithZone() {
        let output = "p1234\ncpostgres\nLpostgres\nf5\nPTCP\nn[fe80::1%lo0]:80\n"
        let result = PortService.parseLsofOutput(output)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].port, 80)
    }

    func testWildcardPort() {
        let output = "p5000\ncpython3\nLjason\nf3\nPTCP\nn*:8000\n"
        let result = PortService.parseLsofOutput(output)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].port, 8000)
    }

    func testMalformedLineNoColonSkipped() {
        let output = "p1234\ncnode\nLpriscilla\nf5\nPTCP\nnmalformed\n"
        let result = PortService.parseLsofOutput(output)
        XCTAssertTrue(result.isEmpty)
    }

    func testNonNumericPortSkipped() {
        let output = "p1234\ncnode\nLpriscilla\nf5\nPTCP\nn*:http\n"
        let result = PortService.parseLsofOutput(output)
        XCTAssertTrue(result.isEmpty)
    }

    func testMultiProcessOutput() {
        let output = [
            "p47291", "cnode", "Lpriscilla", "f24", "PTCP", "n*:3000",
            "p1287", "cpostgres", "Lpostgres", "f5", "PTCP", "n[::1]:5432"
        ].joined(separator: "\n")
        let result = PortService.parseLsofOutput(output)
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].pid, 47291)
        XCTAssertEqual(result[1].pid, 1287)
    }

    func testTruncatedCommandPreserved() {
        let output = "p100\ncpython3.12_lon\nLuser\nf3\nPTCP\nn*:8000\n"
        let result = PortService.parseLsofOutput(output)
        XCTAssertEqual(result[0].processName, "python3.12_lon")
    }
}
