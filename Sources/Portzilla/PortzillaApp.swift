import SwiftUI

@main
struct PortzillaApp: App {
    var body: some Scene {
        MenuBarExtra {
            Text("Portzilla")
                .padding()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "powerplug")
                Text("0")
                    .font(.system(size: 11, weight: .medium))
            }
        }
        .menuBarExtraStyle(.window)
    }
}
