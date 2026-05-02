import SwiftUI

struct RecordingControls: View {
    @EnvironmentObject var captureManager: CaptureManager
    @AppStorage("lastSource") private var lastSource: String = "region"
    @AppStorage("defaultFormat") private var defaultFormat: String = "gif"
    @State private var showSavePanel = false
    @State private var savedURL: URL?
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var showError = false
    @State private var errorMessage = ""

    private var currentSource: RecordingSource {
        RecordingSource(rawValue: lastSource) ?? .region
    }

    private var currentFormat: OutputFormat {
        OutputFormat(rawValue: defaultFormat) ?? .gif
    }

    private var hasStyleApplied: Bool {
        let bg = UserDefaults.standard.string(forKey: "backgroundStyle") ?? "none"
        let chrome = UserDefaults.standard.string(forKey: "chromeType") ?? "none"
        return bg != "none" || chrome != "none"
    }

    var body: some View {
        VStack(spacing: 0) {
            headerView

            Divider()

            controlsView
                .padding()
        }
        .frame(width: 300)
        .background(Color(NSColor.controlBackgroundColor))
        .sheet(isPresented: $showSavePanel) {
            if let url = savedURL {
                SavePanelView(sourceURL: url, onDismiss: {
                    showSavePanel = false
                    savedURL = nil
                })
            }
        }
        .overlay(
            ToastView(message: toastMessage, isShowing: $showToast)
                .padding(.top, 8),
            alignment: .top
        )
        .alert("Recording Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    private var headerView: some View {
        HStack {
            HStack(spacing: 6) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                    .shadow(color: statusColor.opacity(0.6), radius: isRecording ? 4 : 0)
                    .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: isRecording)

                Text(statusText)
                    .font(.system(size: 13, weight: .semibold))

                if hasStyleApplied {
                    Image(systemName: "paintpalette.fill")
                        .font(.caption2)
                        .foregroundColor(.accentColor)
                        .transition(.opacity)
                }
            }

            Spacer()

            if case .recording = captureManager.state {
                Text(captureManager.estimatedFileSize)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var controlsView: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Frame Rate")
                        .font(.system(size: 12, weight: .medium))
                    Spacer()
                    Text("\(Int(captureManager.currentFPS)) FPS")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.accentColor)
                        .monospacedDigit()
                }

                Slider(value: $captureManager.currentFPS, in: 5...30, step: 1)
                    .tint(.accentColor)
            }

            HStack {
                Text("Format")
                    .font(.system(size: 12, weight: .medium))
                Spacer()
                Picker("", selection: $defaultFormat) {
                    ForEach(OutputFormat.allCases) { format in
                        Text(format.rawValue).tag(format.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 120)
            }

            Picker("Source", selection: $lastSource) {
                ForEach(RecordingSource.allCases) { source in
                    Label(source.label, systemImage: source.icon)
                        .tag(source.rawValue)
                }
            }
            .pickerStyle(.segmented)

            HStack {
                Image(systemName: "info.circle")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("Lower FPS = smaller file")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }

            Divider()

            Button(action: handleMainAction) {
                HStack(spacing: 8) {
                    Image(systemName: isRecording ? "stop.fill" : "record.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                    Text(actionButtonLabel)
                        .font(.system(size: 14, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .tint(isRecording ? .red : .accentColor)
            .disabled(captureManager.state == .processing || isSelecting)
            .shadow(color: isRecording ? .red.opacity(0.3) : .accentColor.opacity(0.3), radius: 8, x: 0, y: 2)

            if captureManager.state == .processing {
                VStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text(captureManager.outputFormat == .mp4 ? "Saving video..." : "Encoding GIF...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if case .recording = captureManager.state {
                HStack {
                    Image(systemName: "film")
                        .font(.caption2)
                    Text("\(captureManager.frameCount) frames captured")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }

            HStack {
                Spacer()
                Text(shortcutHint)
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.7))
            }
        }
    }

    private func handleMainAction() {
        Task {
            switch captureManager.state {
            case .idle:
                captureManager.source = currentSource
                captureManager.outputFormat = currentFormat
                await captureManager.startSelection()
                if captureManager.state == .idle {
                    errorMessage = "Screen Recording permission is required. Please grant it in System Settings \u{2192} Privacy & Security \u{2192} Screen Recording."
                    showError = true
                }
            case .recording:
                savedURL = await captureManager.stopRecording()
                if savedURL != nil {
                    showSavePanel = true
                }
            default:
                break
            }
        }
    }

    private var isRecording: Bool {
        if case .recording = captureManager.state { return true }
        return false
    }

    private var isSelecting: Bool {
        captureManager.state == .selectingRegion || captureManager.state == .selectingWindow
    }

    private var actionButtonLabel: String {
        if case .recording = captureManager.state {
            return "Stop Recording"
        }
        switch currentSource {
        case .region: return "Select Area & Record"
        case .window: return "Select Window & Record"
        case .application: return "Select App & Record"
        case .fullDisplay: return "Start Recording"
        }
    }

    private var shortcutHint: String {
        switch currentSource {
        case .region: return "\u{2318}\u{21E7}4 to quick record"
        case .window: return "\u{2318}\u{21E7}4 to quick record"
        case .application: return "\u{2318}\u{21E7}4 to quick record"
        case .fullDisplay: return "\u{2318}\u{21E7}4 to quick record"
        }
    }

    private var statusColor: Color {
        switch captureManager.state {
        case .idle: return .green
        case .selectingRegion, .selectingWindow: return .yellow
        case .recording: return .red
        case .processing: return .blue
        }
    }

    private var statusText: String {
        switch captureManager.state {
        case .idle: return "Ready"
        case .selectingRegion: return "Select Area..."
        case .selectingWindow: return "Select Window..."
        case .recording: return "Recording"
        case .processing: return "Processing"
        }
    }
}

struct SavePanelView: View {
    let sourceURL: URL
    let onDismiss: () -> Void

    @State private var showPreview = false
    @State private var fileSize: String = ""

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.15))
                    .frame(width: 60, height: 60)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.green)
            }

            VStack(spacing: 4) {
                Text(sourceURL.pathExtension == "mp4" ? "Video Ready!" : "GIF Ready!")
                    .font(.system(size: 18, weight: .bold))
                Text("\(fileSize)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if sourceURL.pathExtension != "mp4", let image = NSImage(contentsOf: sourceURL) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 200)
                    .cornerRadius(8)
                    .shadow(radius: 4)
            }

            HStack(spacing: 12) {
                if sourceURL.pathExtension != "mp4" {
                    Button("Copy") {
                        if let image = NSImage(contentsOf: sourceURL) {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.writeObjects([image])
                        }
                        onDismiss()
                    }
                    .buttonStyle(.bordered)
                }

                Button("Save As...") {
                    saveFile()
                    onDismiss()
                }
                .buttonStyle(.borderedProminent)

                Button("Open") {
                    NSWorkspace.shared.open(sourceURL)
                    onDismiss()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(24)
        .frame(width: 360)
        .onAppear {
            calculateFileSize()
        }
    }

    private func calculateFileSize() {
        do {
            let attrs = try FileManager.default.attributesOfItem(atPath: sourceURL.path)
            if let size = attrs[.size] as? Int64 {
                let mb = Double(size) / 1_048_576
                fileSize = String(format: "%.2f MB", mb)
            }
        } catch {
            fileSize = "Unknown size"
        }
    }

    private func saveFile() {
        let panel = NSSavePanel()
        if sourceURL.pathExtension == "mp4" {
            panel.allowedContentTypes = [.mpeg4Movie]
            panel.nameFieldStringValue = "ScreenRecording-\(formattedDate()).mp4"
        } else {
            panel.allowedContentTypes = [.gif]
            panel.nameFieldStringValue = "ScreenRecording-\(formattedDate()).gif"
        }
        panel.canCreateDirectories = true

        if panel.runModal() == .OK, let dest = panel.url {
            do {
                if FileManager.default.fileExists(atPath: dest.path) {
                    try FileManager.default.removeItem(at: dest)
                }
                try FileManager.default.copyItem(at: sourceURL, to: dest)
            } catch {
                print("Save failed: \(error)")
            }
        }
    }

    private func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return formatter.string(from: Date())
    }
}

struct ToastView: View {
    let message: String
    @Binding var isShowing: Bool

    var body: some View {
        if isShowing {
            Text(message)
                .font(.caption)
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.75))
                .cornerRadius(16)
                .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}
