import AppKit
import ScreenCaptureKit
import SwiftUI

struct DisplayInfo: Identifiable {
    let id: String
    let name: String
    let width: Int
    let height: Int
    let display: SCDisplay
}

class DisplayPicker {
    static private var window: NSWindow?
    static private var completion: ((SCDisplay) -> Void)?

    static func show(displays: [SCDisplay], completion: @escaping (SCDisplay) -> Void) {
        self.completion = completion
        let frame = NSScreen.main!.frame
        let view = DisplayPickerView(displays: displays) { selectedDisplay in
            hide()
            completion(selectedDisplay)
        }
        window = NSWindow(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        window?.level = .screenSaver
        window?.isOpaque = false
        window?.backgroundColor = NSColor.black.withAlphaComponent(0.5)
        window?.contentView = view
        window?.orderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    static func hide() {
        window?.orderOut(nil)
        window = nil
    }
}

struct DisplayPickerView: NSViewRepresentable {
    let displays: [SCDisplay]
    let onSelect: (SCDisplay) -> Void

    func makeNSView(context: Context) -> NSView {
        let hosting = NSHostingController(rootView: DisplayPickerContent(displays: displays, onSelect: onSelect))
        return hosting.view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

struct DisplayPickerContent: View {
    let displays: [SCDisplay]
    let onSelect: (SCDisplay) -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("Select Display")
                .font(.title)
                .foregroundColor(.white)
            ForEach(displays.indices, id: \.self) { i in
                let d = displays[i]
                Button(action: { onSelect(d) }) {
                    VStack {
                        Text("Display \(i + 1)")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("\(d.width) x \(d.height)")
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding()
                    .frame(width: 200)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
