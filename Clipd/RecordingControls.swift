import SwiftUI

struct RecordingControls: View {
    @StateObject private var captureManager = CaptureManager()
    @State private var sourceURL: URL?
    @AppStorage("fps") private var fps: Double = 15
    @AppStorage("defaultSource") private var defaultSource: String = "region"
    @AppStorage("defaultFormat") private var defaultFormat: String = "gif"

    var body: some View {
        VStack(spacing: 16) {
            if let url = sourceURL {
                SavePanelView(sourceURL: url, format: currentFormat) { sourceURL = nil }
            } else {
                recordingControls
            }
        }
        .padding()
        .frame(width: 280)
        .task {
            await captureManager.requestPermission()
            captureManager.source = RecordingSource(rawValue: defaultSource) ?? .region
            captureManager.outputFormat = OutputFormat(rawValue: defaultFormat) ?? .gif
        }
    }

    private var currentFormat: OutputFormat {
        OutputFormat(rawValue: defaultFormat) ?? .gif
    }

    private var recordingControls: some View {
        VStack(spacing: 16) {
            if captureManager.state == .recording {
                HStack {
                    Circle().fill(.red).frame(width: 10, height: 10)
                    Text("Recording...")
                }
            } else if captureManager.state == .encoding {
                Text(captureManager.outputFormat == .mp4 ? "Saving video..." : "Encoding GIF...")
            } else {
                Text("Ready to record")
                    .foregroundColor(.gray)
            }

            Picker("Source", selection: Binding(
                get: { captureManager.source },
                set: { captureManager.source = $0; defaultSource = $0.rawValue }
            )) {
                ForEach(RecordingSource.allCases) { source in
                    Text(source.label).tag(source)
                }
            }
            .pickerStyle(.segmented)

            Picker("Format", selection: Binding(
                get: { captureManager.outputFormat },
                set: { captureManager.outputFormat = $0; defaultFormat = $0.rawValue }
            )) {
                ForEach(OutputFormat.allCases) { format in
                    Text(format.rawValue.uppercased()).tag(format)
                }
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("FPS")
                        .font(.caption)
                    Spacer()
                    Text("\(Int(fps))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Slider(value: $fps, in: 5...30, step: 5)
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
    let format: OutputFormat
    let onDismiss: () -> Void
    @State private var showSavePanel = false

    var body: some View {
        VStack(spacing: 12) {
            Text(format == .mp4 ? "Video Ready!" : "GIF Ready!")
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
        .fileExporter(isPresented: $showSavePanel, document: MediaFile(url: sourceURL), contentType: format == .gif ? .gif : .mpeg4Movie) { _ in }
        .onDisappear { onDismiss() }
    }
}

struct MediaFile: FileDocument {
    var url: URL
    static var readableContentTypes: [UTType] { [.gif, .mpeg4Movie] }
    init(url: URL) { self.url = url }
    init(configuration: ReadConfiguration) throws { url = URL(fileURLWithPath: "/tmp/placeholder") }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        try FileWrapper(contentsOf: url, options: []) ?? FileWrapper(data: Data())
    }
}
