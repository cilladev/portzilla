import SwiftUI

struct HeaderView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "powerplug")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            Text("Portzilla")
                .font(.system(size: 13, weight: .medium))

            Text("⌃⌥P")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(Color(NSColor.tertiaryLabelColor))
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(4)

            Spacer()

            Button {
                Task { await state.debouncedRefresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 14))
                    .rotationEffect(.degrees(state.isLoading ? 360 : 0))
                    .animation(
                        state.isLoading ? .linear(duration: 0.6).repeatForever(autoreverses: false) : .default,
                        value: state.isLoading
                    )
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            .frame(width: 26, height: 26)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
            )

            Button {} label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 14))
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            .frame(width: 26, height: 26)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
            )
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
    }
}
