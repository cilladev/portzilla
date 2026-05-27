import SwiftUI

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    @Published var ports: [PortInfo] = []
    @Published var filter: String = ""
    @Published var isLoading: Bool = false
    @Published var toast: String? = nil
    @Published var isPopoverOpen: Bool = false
    @Published var permissionAlert: PortInfo? = nil

    let portService = PortService()
    private var refreshTimer: Timer?

    var filteredPorts: [PortInfo] {
        let trimmed = filter.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return ports }
        let query = trimmed.lowercased()
        return ports.filter { port in
            String(port.port).contains(query) ||
            String(port.pid).contains(query) ||
            port.processName.lowercased().contains(query) ||
            port.command.lowercased().contains(query)
        }
    }

    var listeningCount: Int { ports.count }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        do {
            ports = try await portService.listListeningPorts()
        } catch {
            showToast(error.localizedDescription)
        }
    }

    func kill(_ port: PortInfo) async {
        guard port.isOwnedByCurrentUser else {
            permissionAlert = port
            return
        }

        do {
            try portService.kill(pid: port.pid, force: false)
        } catch {
            showToast(error.localizedDescription)
            return
        }

        ports.removeAll { $0.id == port.id }
        showToast("Killed \(port.processName) on :\(String(port.port))")

        try? await Task.sleep(nanoseconds: 1_000_000_000)
        if portService.isProcessAlive(pid: port.pid) {
            try? portService.kill(pid: port.pid, force: true)
        }

        try? await Task.sleep(nanoseconds: 300_000_000)
        await refresh()
    }

    func killAllDevPorts() async {
        let killable = ports.filter { $0.isOwnedByCurrentUser && $0.pid != getpid() }
        var killedCount = 0
        for port in killable {
            do {
                try portService.kill(pid: port.pid, force: false)
                killedCount += 1
            } catch {}
        }
        showToast("Killed \(killedCount) processes")

        try? await Task.sleep(nanoseconds: 1_000_000_000)
        for port in killable where portService.isProcessAlive(pid: port.pid) {
            try? portService.kill(pid: port.pid, force: true)
        }

        try? await Task.sleep(nanoseconds: 300_000_000)
        await refresh()
    }

    func togglePopover() {
        for window in NSApp.windows where window.className.contains("StatusBarWindow") {
            if window.isVisible {
                window.orderOut(nil)
            } else {
                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
            }
            return
        }
    }

    private var lastRefreshTime: Date = .distantPast

    func debouncedRefresh() async {
        guard Date().timeIntervalSince(lastRefreshTime) > 0.2 else { return }
        lastRefreshTime = Date()
        await refresh()
    }

    func showToast(_ message: String) {
        toast = message
        Task {
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            if self.toast == message {
                self.toast = nil
            }
        }
    }

    func startBackgroundRefresh() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, !self.isPopoverOpen else { return }
                await self.refresh()
            }
        }
    }

    func stopBackgroundRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
}
