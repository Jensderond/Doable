import SwiftUI

struct MenuContentView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Doable")
                .font(.headline)
            Text("Hello from the menubar.")
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(width: 320)
    }
}
