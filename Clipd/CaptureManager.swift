import ScreenCaptureKit
import SwiftUI

@MainActor
class CaptureManager: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var hasPermission = false

    func requestPermission() async {
        hasPermission = await SCShareableContent.current != nil
    }

    func startRecording() async {
        // TODO: implement screen capture
    }

    func stopRecording() async {
        isRecording = false
    }
}
