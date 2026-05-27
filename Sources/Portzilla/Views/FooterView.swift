import SwiftUI

struct FooterView: View {
    @EnvironmentObject var state: AppState
    @State private var isKillAllHovering = false

    var body: some View {
        HStack {
            Text("\(state.listeningCount) listening port\(state.listeningCount == 1 ? "" : "s")")
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            Spacer()

            Button {
                Task { await state.killAllDevPorts() }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "flame")
                        .font(.system(size: 13))
                    Text("Kill all dev ports")
                        .font(.system(size: 12))
                }
                .padding(.horizontal, 12)
                .frame(height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isKillAllHovering ? Color.red.opacity(0.1) : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isKillAllHovering ? Color.red.opacity(0.3) : Color(NSColor.separatorColor), lineWidth: 0.5)
                )
                .foregroundColor(isKillAllHovering ? .red : .secondary)
            }
            .buttonStyle(.plain)
            .onHover { isKillAllHovering = $0 }
        }
        .padding(.horizontal, 14)
        .frame(height: 40)
        .background(Color(NSColor.controlBackgroundColor))
    }
}
