import SwiftUI

struct RecordingControls: View {
    @StateObject private var captureManager = CaptureManager()

    var body: some View {
        VStack(spacing: 16) {
            if captureManager.state == .recording {
                HStack {
                    Circle().fill(.red).frame(width: 10, height: 10)
                    Text("Recording...")
                }
            } else {
                Text("Ready to record")
                    .foregroundColor(.gray)
            }

            Button(action: {
                Task {
                    if captureManager.state == .recording {
                        await captureManager.stopRecording()
                    } else {
                        captureManager.startRegionSelection()
                    }
                }
            }) {
                Text(captureManager.state == .recording ? "Stop" : "Record")
                    .frame(maxWidth: .infinity)
                    .padding(8)
                    .background(captureManager.state == .recording ? Color.red : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(6)
            }
        }
        .padding()
        .frame(width: 280, height: 120)
        .task {
            await captureManager.requestPermission()
        }
    }
}
