import SwiftUI
import Combine

@main
struct PortzillaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private let state = AppState.shared
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateMenuBarButton()

        let contentView = PopoverContentView()
            .environmentObject(state)

        popover.contentSize = NSSize(width: 420, height: 520)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: contentView)
        popover.delegate = self

        statusItem.button?.action = #selector(togglePopover)
        statusItem.button?.target = self

        state.$ports
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateMenuBarButton() }
            .store(in: &cancellables)

        Task {
            await state.refresh()
            state.startBackgroundRefresh()
        }
    }

    private func updateMenuBarButton() {
        guard let button = statusItem.button else { return }
        let count = state.listeningCount
        if count > 0 {
            button.image = NSImage(systemSymbolName: "powerplug", accessibilityDescription: "Portzilla")
            button.title = " \(count)"
            button.imagePosition = .imageLeading
        } else {
            button.image = NSImage(systemSymbolName: "powerplug", accessibilityDescription: "Portzilla")
            button.title = ""
        }
        button.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)
    }

    @objc func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else if let button = statusItem.button {
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
            state.isPopoverOpen = true
            Task { await state.refresh() }
        }
    }

    func popoverDidClose(_ notification: Notification) {
        state.isPopoverOpen = false
    }
}

struct PopoverContentView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
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
        .frame(width: 420)
    }
}
