import SwiftUI

@main
struct PortzillaApp: App {
    @StateObject private var state = AppState.shared

    init() {
        HotkeyManager.register()
    }

    var body: some Scene {
        MenuBarExtra {
            VStack(spacing: 0) {
                HeaderView()
                Divider()
                SearchBarView()
                Divider()
                PortListView()
                Divider()
                FooterView()

                Divider()
                Button("Quit Portzilla") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .overlay(alignment: .bottom) {
                if let toast = state.toast {
                    ToastView(message: toast)
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.18), value: state.toast)
                        .padding(.bottom, 48)
                }
            }
            .frame(width: 420)
            .environmentObject(state)
            .task {
                await state.refresh()
                state.startBackgroundRefresh()
            }
            .onAppear { state.isPopoverOpen = true }
            .onDisappear { state.isPopoverOpen = false }
            .alert(
                "Cannot kill process",
                isPresented: Binding(
                    get: { state.permissionAlert != nil },
                    set: { if !$0 { state.permissionAlert = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                if let port = state.permissionAlert {
                    Text("Cannot kill \(port.user)'s process. Run with elevated permissions to terminate root-owned ports.")
                }
            }
            .alert(
                "Kill \(String(state.killAllConfirmation.count)) dev port\(state.killAllConfirmation.count == 1 ? "" : "s")?",
                isPresented: Binding(
                    get: { !state.killAllConfirmation.isEmpty },
                    set: { if !$0 { state.killAllConfirmation = [] } }
                )
            ) {
                Button("Kill All", role: .destructive) {
                    Task { await state.killAllDevPorts() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(state.killAllConfirmation.map { "\(String($0.port)) (\($0.processName))" }.joined(separator: ", "))
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "powerplug")
                if state.listeningCount > 0 {
                    Text(String(state.listeningCount))
                        .font(.system(size: 11, weight: .medium))
                }
            }
        }
        .menuBarExtraStyle(.window)
    }
}
