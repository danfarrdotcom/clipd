import ScreenCaptureKit
import CoreGraphics
import CoreImage
import Combine
import AVFoundation

enum RecordingSource: String, CaseIterable, Identifiable {
    case region
    case window
    case application
    case fullDisplay

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .region: return "rectangle.dashed"
        case .window: return "macwindow"
        case .application: return "app"
        case .fullDisplay: return "display"
        }
    }

    var label: String {
        switch self {
        case .region: return "Region"
        case .window: return "Window"
        case .application: return "App"
        case .fullDisplay: return "Display"
        }
    }
}

enum RecordingState: Equatable {
    case idle
    case selectingRegion
    case selectingWindow
    case recording(startTime: Date)
    case processing

    static func == (lhs: RecordingState, rhs: RecordingState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.selectingRegion, .selectingRegion),
             (.selectingWindow, .selectingWindow), (.processing, .processing):
            return true
        case let (.recording(l), .recording(r)):
            return l == r
        default:
            return false
        }
    }
}

enum RecordingError: Error, LocalizedError {
    case windowNotFound
    case appNotFound
    case mp4WriterFailed

    var errorDescription: String? {
        switch self {
        case .windowNotFound: return "Selected window not found"
        case .appNotFound: return "Selected application not found"
        case .mp4WriterFailed: return "Failed to initialize video recording"
        }
    }
}

@MainActor
class CaptureManager: NSObject, ObservableObject {
    @Published var state: RecordingState = .idle
    @Published var frameCount: Int = 0
    @Published var currentFPS: Double = 15.0
    @Published var estimatedFileSize: String = ""
    @Published var outputFormat: OutputFormat = .gif

    private var stream: SCStream?
    private var frames: [CGImage] = []
    nonisolated(unsafe) private var assetWriter: AVAssetWriter?
    nonisolated(unsafe) private var assetWriterInput: AVAssetWriterInput?
    private var captureQueue = DispatchQueue(label: "com.clipd.capture", qos: .userInitiated)
    private var startTime: Date?

    private var compositor = FrameCompositor()

    // Thread-safe state for nonisolated SCStreamOutput delegate
    nonisolated(unsafe) private var _streamOutputFormat: OutputFormat = .gif
    nonisolated(unsafe) private var _streamRecordedSize: CGSize?
    nonisolated(unsafe) private var _streamMP4CompositionActive: Bool = false
    nonisolated(unsafe) private var _streamCompositor: FrameCompositor?

    var source: RecordingSource = .region
    var selectedWindowID: CGWindowID?
    var selectedAppBundleID: String?
    var selectedDisplay: SCDisplay?
    var selectedRect: CGRect = .zero

    private var selectedSCWindow: SCWindow? {
        get async {
            do {
                let content = try await SCShareableContent.current
                return content.windows.first { $0.windowID == selectedWindowID }
            } catch {
                return nil
            }
        }
    }

    func requestPermission() async -> Bool {
        do {
            _ = try await SCShareableContent.current
            return true
        } catch {
            print("Screen recording permission denied: \(error)")
            return false
        }
    }

    func startSelection() {
        switch source {
        case .region:
            state = .selectingRegion
            RegionSelector.show { [weak self] rect in
                guard let self = self else { return }
                self.selectedRect = rect
                Task {
                    await self.startRecording()
                }
            }
        case .window:
            state = .selectingWindow
            WindowPicker.show { [weak self] window in
                guard let self = self else { return }
                self.selectedWindowID = window.windowID
                Task {
                    await self.startRecording()
                }
            }
        case .application:
            state = .selectingWindow
            WindowPicker.show { [weak self] window in
                guard let self = self else { return }
                self.selectedWindowID = window.windowID
                self.selectedAppBundleID = window.owningApplication?.bundleIdentifier
                Task {
                    await self.startRecording()
                }
            }
        case .fullDisplay:
            Task {
                do {
                    let content = try await SCShareableContent.current
                    if content.displays.count > 1 {
                        self.state = .selectingWindow
                        DisplayPicker.show(displays: content.displays) { display in
                            self.selectedDisplay = display
                            Task {
                                await self.startRecording()
                            }
                        }
                    } else if let single = content.displays.first {
                        self.selectedDisplay = single
                        await self.startRecording()
                    }
                } catch {
                    self.state = .idle
                }
            }
        }
    }

    func startRecording() async {
        guard await requestPermission() else {
            state = .idle
            return
        }

        do {
            let content = try await SCShareableContent.current
            guard let display = content.displays.first else {
                state = .idle
                return
            }

            let filter = try createContentFilter(from: source, content: content, display: display)

            let config = SCStreamConfiguration()
            let rect = await sourceRect(from: source, display: display)
            config.width = max(1, min(Int(rect.width), 1920))
            config.height = max(1, min(Int(rect.height), 1200))
            config.sourceRect = rect
            config.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(currentFPS))
            config.queueDepth = 5
            config.showsCursor = UserDefaults.standard.bool(forKey: "showCursor")
            if #available(macOS 14.0, *) {
                config.captureResolution = .automatic
            }

            if outputFormat == .mp4 {
                try await setupMP4Writer()
            }

            stream = SCStream(filter: filter, configuration: config, delegate: self)
            try stream?.addStreamOutput(self, type: .screen, sampleHandlerQueue: captureQueue)

            frames.removeAll()
            frameCount = 0
            _streamOutputFormat = outputFormat
            _streamRecordedSize = nil
            _streamMP4CompositionActive = false
            _streamCompositor = compositor
            startTime = Date()

            try await stream?.startCapture()
            state = .recording(startTime: Date())

        } catch {
            print("Failed to start recording: \(error)")
            state = .idle
        }
    }

    func stopRecording() async -> URL? {
        try? await stream?.stopCapture()
        stream = nil
        state = .processing

        configureCompositor()

        let url: URL?
        if outputFormat == .mp4 {
            url = await finalizeMP4()
        } else {
            if compositor.chromeType != .none || compositor.backgroundStyle != .none {
                composeAllFrames()
            }
            url = await encodeGIF()
        }

        await MainActor.run {
            state = .idle
            frameCount = 0
            estimatedFileSize = ""
            assetWriter = nil
            assetWriterInput = nil
        }

        return url
    }

    private func createContentFilter(from source: RecordingSource, content: SCShareableContent, display: SCDisplay) throws -> SCContentFilter {
        switch source {
        case .region:
            return SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])

        case .window:
            guard let scWindow = content.windows.first(where: { $0.windowID == selectedWindowID }) else {
                throw RecordingError.windowNotFound
            }
            let allOtherApps = content.applications.filter { $0.bundleIdentifier != scWindow.owningApplication?.bundleIdentifier }
            return SCContentFilter(display: display, excludingApplications: allOtherApps, exceptingWindows: [])

        case .application:
            guard let app = content.applications.first(where: { $0.bundleIdentifier == selectedAppBundleID }) else {
                throw RecordingError.appNotFound
            }
            return SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])

        case .fullDisplay:
            return SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
        }
    }

    private func sourceRect(from source: RecordingSource, display: SCDisplay) async -> CGRect {
        switch source {
        case .region:
            return selectedRect
        case .window:
            guard let window = await selectedSCWindow else { return display.frame }
            return window.frame
        case .application:
            return display.frame
        case .fullDisplay:
            return display.frame
        }
    }

    private func setupMP4Writer() async throws {
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("recording-\(UUID().uuidString).mp4")

        assetWriter = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)

        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: 1920,
            AVVideoHeightKey: 1200,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 2_500_000,
                AVVideoExpectedSourceFrameRateKey: Int(currentFPS),
                AVVideoMaxKeyFrameIntervalKey: 30,
            ] as [String: Any]
        ]

        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = true

        assetWriter?.add(input)
        assetWriterInput = input
    }

    private func finalizeMP4() async -> URL? {
        await MainActor.run {
            self.assetWriterInput?.markAsFinished()
        }

        return await withCheckedContinuation { continuation in
            self.assetWriter?.finishWriting {
                if self.assetWriter?.status == .completed,
                   let outputURL = self.assetWriter?.outputURL {
                    continuation.resume(returning: outputURL)
                } else {
                    print("MP4 writing failed: \(self.assetWriter?.error?.localizedDescription ?? "unknown")")
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private func configureCompositor() {
        let bgStyleRaw = UserDefaults.standard.string(forKey: "backgroundStyle") ?? "none"
        let chromeRaw = UserDefaults.standard.string(forKey: "chromeType") ?? "none"

        let bgStyle = BackgroundStyle(rawValue: bgStyleRaw) ?? .none
        let chrome = ChromeType(rawValue: chromeRaw) ?? .none

        compositor.backgroundStyle = bgStyle
        compositor.chromeType = chrome

        if bgStyle == .transparent && outputFormat == .mp4 {
            compositor.backgroundStyle = .none
        }

        if let rgba = parseRGBA(UserDefaults.standard.string(forKey: "solidColorRGBA")) {
            compositor.solidColor = rgba
        }
        if let rgba = parseRGBA(UserDefaults.standard.string(forKey: "gradientTopRGBA")) {
            compositor.gradientTop = rgba
        }
        if let rgba = parseRGBA(UserDefaults.standard.string(forKey: "gradientBottomRGBA")) {
            compositor.gradientBottom = rgba
        }

        let isMP4 = outputFormat == .mp4 && (chrome != .none || bgStyle != .none)
        _streamOutputFormat = outputFormat
        _streamMP4CompositionActive = isMP4
        _streamCompositor = compositor
    }

    private func parseRGBA(_ rgbaString: String?) -> CGColor? {
        guard let str = rgbaString else { return nil }
        let components = str.split(separator: ",").compactMap { Double($0) }
        guard components.count == 4 else { return nil }
        return CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: components.map { CGFloat($0) })
    }

    private func composeAllFrames() {
        guard let firstFrame = frames.first else { return }
        let originalSize = CGSize(width: firstFrame.width, height: firstFrame.height)

        var composed: [CGImage] = []
        for frame in frames {
            if let composedFrame = compositor.compose(frame: frame, originalSize: originalSize) {
                composed.append(composedFrame)
            } else {
                composed.append(frame)
            }
        }
        frames = composed
    }

    private func encodeGIF() async -> URL? {
        guard !frames.isEmpty else { return nil }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("recording-\(UUID().uuidString).gif")

        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            UTType.gif.identifier as CFString,
            frames.count,
            nil
        ) else { return nil }

        let gifProperties = [
            kCGImagePropertyGIFDictionary: [
                kCGImagePropertyGIFLoopCount: 0
            ]
        ] as CFDictionary
        CGImageDestinationSetProperties(destination, gifProperties)

        let delay = 1.0 / currentFPS
        let frameProperties = [
            kCGImagePropertyGIFDictionary: [
                kCGImagePropertyGIFDelayTime: delay
            ]
        ] as CFDictionary

        for (index, frame) in frames.enumerated() {
            CGImageDestinationAddImage(destination, frame, frameProperties)

            if index % 10 == 0 {
                await MainActor.run {
                    self.estimatedFileSize = "Encoding: \(index)/\(frames.count) frames"
                }
            }
        }

        guard CGImageDestinationFinalize(destination) else { return nil }

        if let optimizedURL = await optimizeGIF(input: url) {
            return optimizedURL
        }

        return url
    }

    private func optimizeGIF(input: URL) async -> URL? {
        let output = FileManager.default.temporaryDirectory
            .appendingPathComponent("optimized-\(UUID().uuidString).gif")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/gifsicle")
        process.arguments = [
            "--optimize=3",
            "--colors=128",
            "--lossy=30",
            "-o", output.path,
            input.path
        ]

        do {
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus == 0 {
                try? FileManager.default.removeItem(at: input)
                return output
            }
        } catch {
            print("gifsicle not available, using unoptimized GIF")
        }

        return nil
    }
}

extension CaptureManager: SCStreamOutput {
    nonisolated func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen else { return }

        let localFormat = _streamOutputFormat
        let localCompositionActive = _streamMP4CompositionActive
        let localCompositor = _streamCompositor
        let localRecordedSize = _streamRecordedSize

        if localRecordedSize == nil, let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
            let width = CVPixelBufferGetWidth(imageBuffer)
            let height = CVPixelBufferGetHeight(imageBuffer)
            let size = CGSize(width: width, height: height)
            _streamRecordedSize = size

            Task { @MainActor in
                self.estimatedFileSize = "Recording: \(Int(size.width))x\(Int(size.height))"
            }
            return
        }

        if localFormat == .mp4, let input = assetWriterInput,
           input.isReadyForMoreMediaData {

            var bufferToWrite = sampleBuffer
            if localCompositionActive, let size = _streamRecordedSize,
               let compositor = localCompositor {
                if let composed = compositor.compose(sampleBuffer: sampleBuffer, originalSize: size) {
                    bufferToWrite = composed
                }
            }

            let presentationTime = CMSampleBufferGetPresentationTimeStamp(bufferToWrite)
            if assetWriter?.status == .unknown {
                Task { @MainActor in
                    self.assetWriter?.startWriting()
                    self.assetWriter?.startSession(atSourceTime: presentationTime)
                }
            }
            input.append(bufferToWrite)

            Task { @MainActor in
                self.frameCount += 1
                if let start = self.startTime {
                    let duration = Date().timeIntervalSince(start)
                    self.estimatedFileSize = String(format: "%.1fs", duration)
                }
            }
            return
        }

        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        let context = CIContext(options: nil)

        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }

        Task { @MainActor in
            self.frames.append(cgImage)
            self.frameCount = self.frames.count

            if let start = self.startTime {
                let duration = Date().timeIntervalSince(start)
                let fps = Double(self.frames.count) / duration
                self.estimatedFileSize = String(format: "%.1f fps | %.1fs", fps, duration)
            }
        }
    }
}

extension CaptureManager: SCStreamDelegate {
    nonisolated func stream(_ stream: SCStream, didStopWithError error: Error) {
        print("Stream stopped: \(error)")
    }
}
