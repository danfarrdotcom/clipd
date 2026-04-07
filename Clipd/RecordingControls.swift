import SwiftUI

struct RecordingControls: View {
    @StateObject private var captureManager = CaptureManager()

    var body: some View {
        VStack(spacing: 12) {
            Text("Clipd")
                .font(.headline)
            Text("No permission")
                .foregroundColor(.gray)
                .font(.caption)
        }
        .padding()
        .frame(width: 280)
        .task {
            await captureManager.requestPermission()
        }
    }
}
