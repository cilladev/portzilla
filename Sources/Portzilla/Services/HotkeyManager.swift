import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let togglePortzilla = Self("togglePortzilla", default: .init(.p, modifiers: [.control, .option]))
}

enum HotkeyManager {
    static func register() {
        KeyboardShortcuts.onKeyUp(for: .togglePortzilla) {
            Task { @MainActor in
                AppState.shared.togglePopover()
            }
        }
    }
}
