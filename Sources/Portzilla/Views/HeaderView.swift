import SwiftUI

struct HeaderView: View {
    @EnvironmentObject var state: AppState
    @State private var spinDegrees: Double = 0

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "powerplug")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            Text("Portzilla")
                .font(.system(size: 13, weight: .medium))

            Spacer()

            Button {
                Task { await state.debouncedRefresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 14))
                    .rotationEffect(.degrees(spinDegrees))
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            .frame(width: 26, height: 26)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
            )
            .onChange(of: state.isLoading) { loading in
                if loading {
                    withAnimation(.linear(duration: 0.6).repeatForever(autoreverses: false)) {
                        spinDegrees += 360
                    }
                } else {
                    withAnimation(.default) {
                        spinDegrees = 0
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
    }
}
