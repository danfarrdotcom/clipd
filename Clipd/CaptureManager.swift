import ScreenCaptureKit
import SwiftUI
import UniformTypeIdentifiers

enum RecordingState {
    case idle, recording, encoding
}

enum RecordingSource: String, CaseIterable, Identifiable {
    case region, window, app, display

    var id: String { rawValue }
    var label: String {
        switch self {
        case .region: return "Region"
        case .window: return "Window"
        case .app: return "Application"
        case .display: return "Display"
        }
    }
}

@MainActor
class CaptureManager: NSObject, ObservableObject {
    @Published var state: RecordingState = .idle
    @Published var hasPermission = false
    @Published var source: RecordingSource = .region

    private var stream: SCStream?
    private var frames: [CGImage] = []
    private var selectionRect: CGRect?

    func requestPermission() async {
        hasPermission = await SCShareableContent.current != nil
    }

    func startRegionSelection() {
        RegionSelector.show { [weak self] rect in
            Task { await self?.startRecording(with: rect) }
        }
    }

    private func startRecording(with rect: CGRect) async {
        guard let content = try? await SCShareableContent.current else { return }
        guard let display = content.displays.first else { return }
        selectionRect = rect

        let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
        let config = SCStreamConfiguration()
        config.width = Int(display.frame.width) * 2
        config.height = Int(display.frame.height) * 2
        config.sourceRect = rect
        config.showsCursor = true
        config.minimumFrameInterval = CMTime(value: 1, timescale: 15)

        stream = SCStream(filter: filter, configuration: config, delegate: self)
        try? await stream?.addStreamOutput(self, type: .screen, sampleHandlerQueue: .main)
        try? await stream?.startCapture()
        state = .recording
    }

    func stopRecording() async {
        stream?.stopCapture()
        stream = nil
        state = .encoding

        let url = await encodeGIF()
        state = .idle
    }

    private func encodeGIF() async -> URL? {
        guard !frames.isEmpty else { return nil }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("recording-\(UUID().uuidString).gif")

        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.gif.identifier as CFString, frames.count, nil) else { return nil }

        let gifProperties = [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]]
        let frameProperties = [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 0.1]]

        CGImageDestinationSetProperties(destination, gifProperties)
        for frame in frames {
            CGImageDestinationAddImage(destination, frame, frameProperties as CFDictionary)
        }
        CGImageDestinationFinalize(destination)
        frames.removeAll()
        return url
    }
}

extension CaptureManager: SCStreamOutput, SCStreamDelegate {
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
            frames.append(cgImage)
        }
    }
}
