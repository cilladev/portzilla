import SwiftUI

struct ToastView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.system(size: 12))
            .foregroundColor(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(Color(NSColor.labelColor))
            .cornerRadius(8)
            .shadow(radius: 10)
    }
}
