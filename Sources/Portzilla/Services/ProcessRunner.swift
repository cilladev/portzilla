import Foundation

enum ProcessRunnerError: Error, LocalizedError {
    case timeout
    case launchFailed(Error)

    var errorDescription: String? {
        switch self {
        case .timeout: return "Process timed out"
        case .launchFailed(let error): return "Launch failed: \(error.localizedDescription)"
        }
    }
}

struct ProcessRunner {
    static func run(_ path: String, args: [String], timeout: TimeInterval = 5) throws -> (stdout: String, stderr: String, exitCode: Int32) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = args

        var env = ProcessInfo.processInfo.environment
        env["PATH"] = "/usr/sbin:/usr/bin:/bin:/opt/homebrew/bin:/usr/local/bin"
        process.environment = env

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
        } catch {
            throw ProcessRunnerError.launchFailed(error)
        }

        var didTimeout = false
        let timer = DispatchSource.makeTimerSource()
        timer.schedule(deadline: .now() + timeout)
        timer.setEventHandler {
            didTimeout = true
            process.terminate()
        }
        timer.resume()

        var stdoutResult = Data()
        var stderrResult = Data()
        let group = DispatchGroup()

        group.enter()
        DispatchQueue.global().async {
            stdoutResult = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            group.leave()
        }
        group.enter()
        DispatchQueue.global().async {
            stderrResult = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            group.leave()
        }

        process.waitUntilExit()
        timer.cancel()
        group.wait()

        if didTimeout {
            throw ProcessRunnerError.timeout
        }

        return (
            stdout: String(data: stdoutResult, encoding: .utf8) ?? "",
            stderr: String(data: stderrResult, encoding: .utf8) ?? "",
            exitCode: process.terminationStatus
        )
    }
}
