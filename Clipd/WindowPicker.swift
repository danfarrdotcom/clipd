import AppKit
import ScreenCaptureKit
import SwiftUI

class WindowPicker {
    static private var window: NSWindow?
    static private var completion: ((SCWindow) -> Void)?

    static func show(completion: @escaping (SCWindow) -> Void) {
        self.completion = completion
        let frame = NSScreen.main!.frame
        let view = WindowPickerView(frame: frame) { selectedWindow in
            hide()
            completion(selectedWindow)
        }
        window = NSWindow(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        window?.level = .screenSaver
        window?.isOpaque = false
        window?.backgroundColor = .clear
        window?.contentView = view
        window?.orderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    static func hide() {
        window?.orderOut(nil)
        window = nil
    }
}

struct WindowPickerItem: Identifiable {
    let id: String
    let window: SCWindow
    let thumbnail: NSImage?
    let appName: String
    let title: String
}

struct WindowPickerView: NSViewRepresentable {
    let onSelect: (SCWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = WindowPickerInternalView(frame: NSScreen.main!.frame)
        view.onSelect = onSelect
        view.loadWindows()
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

class WindowPickerInternalView: NSView {
    var onSelect: ((SCWindow) -> Void)?
    private var windows: [WindowPickerItem] = []

    func loadWindows() {
        Task {
            guard let content = try? await SCShareableContent.current else { return }
            let systemBundleIDs = Set(["com.apple.dock", "com.apple.WindowManager", "com.apple.finder"])
            let filtered = content.windows.filter { w in
                w.onScreen && !systemBundleIDs.contains(w.owningApplication?.bundleIdentifier ?? "")
            }
            windows = filtered.map { w in
                let appName = w.owningApplication?.applicationName ?? "Unknown"
                let title = w.title ?? ""
                let thumbnail = SCScreenshotManager.createCGImage(from: w, rect: w.frame)
                    .map { NSImage(cgImage: $0, size: CGSize(width: 200, height: 150)) }
                return WindowPickerItem(id: "\(w.windowID)", window: w, thumbnail: thumbnail, appName: appName, title: title)
            }
            needsDisplay = true
        }
    }
}

struct WindowCard: View {
    let item: WindowPickerItem
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Group {
                    if let thumb = item.thumbnail {
                        Image(nsImage: thumb)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } else {
                        Color.gray.frame(height: 100)
                    }
                }
                .cornerRadius(6)
                .frame(width: 180, height: 120)
                Text(item.appName)
                    .font(.caption)
                    .fontWeight(.medium)
            }
        }
        .buttonStyle(.plain)
    }
}
