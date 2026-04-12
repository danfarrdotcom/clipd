import SwiftUI

struct RecordingControls: View {
    @StateObject private var captureManager = CaptureManager()
    @State private var sourceURL: URL?

    var body: some View {
        VStack(spacing: 16) {
            if let url = sourceURL {
                SavePanelView(sourceURL: url) { sourceURL = nil }
            } else {
                recordingControls
            }
        }
        .padding()
        .frame(width: 280, height: sourceURL != nil ? 140 : 120)
        .task {
            await captureManager.requestPermission()
        }
    }

    private var recordingControls: some View {
        VStack(spacing: 16) {
            if captureManager.state == .recording {
                HStack {
                    Circle().fill(.red).frame(width: 10, height: 10)
                    Text("Recording...")
                }
            } else if captureManager.state == .encoding {
                Text("Encoding GIF...")
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
    }
}

struct SavePanelView: View {
    let sourceURL: URL
    let onDismiss: () -> Void
    @State private var showSavePanel = false

    var body: some View {
        VStack(spacing: 12) {
            Text("GIF Ready!")
                .font(.headline)
            HStack(spacing: 8) {
                Button("Copy") {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.writeObjects([sourceURL as NSURL])
                }
                Button("Save") { showSavePanel = true }
                Button("Open") { NSWorkspace.shared.open(sourceURL) }
            }
        }
        .fileExporter(isPresented: $showSavePanel, document: GIFFile(url: sourceURL), contentType: .gif) { _ in }
        .onDisappear { onDismiss() }
    }
}

struct GIFFile: FileDocument {
    var url: URL
    static var readableContentTypes: [UTType] { [.gif] }
    init(url: URL) { self.url = url }
    init(configuration: ReadConfiguration) throws { url = URL(fileURLWithPath: "/tmp/placeholder.gif") }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        try FileWrapper(contentsOf: url, options: []) ?? FileWrapper(data: Data())
    }
}
