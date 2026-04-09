import ScreenCaptureKit
import SwiftUI
import UniformTypeIdentifiers

enum RecordingState {
    case idle, recording, encoding
}

@MainActor
class CaptureManager: NSObject, ObservableObject {
    @Published var state: RecordingState = .idle
    @Published var hasPermission = false

    private var stream: SCStream?
    private var frames: [CGImage] = []

    func requestPermission() async {
        hasPermission = await SCShareableContent.current != nil
    }

    func startRecording() async {
        guard let content = try? await SCShareableContent.current else { return }
        guard let display = content.displays.first else { return }

        let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
        let config = SCStreamConfiguration()
        config.width = Int(display.frame.width) * 2
        config.height = Int(display.frame.height) * 2
        config.showsCursor = true
        config.minimumFrameInterval = CMTime(value: 1, timescale: 15)

        stream = SCStream(filter: filter, configuration: config, delegate: self)
        try? await stream?.addStreamOutput(self, type: .screen, sampleHandlerQueue: .main)
        try? await stream?.startCapture()
        state = .recording
    }

    func stopRecording() {
        stream?.stopCapture()
        stream = nil
        state = .idle
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
