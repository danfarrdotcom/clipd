import SwiftUI
import AppKit
import ScreenCaptureKit

struct DisplayInfo: Identifiable {
    let id: UUID
    let display: SCDisplay
    let name: String
    let resolution: String
}

class DisplayPicker {
    static var selectionCallback: ((SCDisplay) -> Void)?
    static var overlayWindow: NSWindow?

    @MainActor
    static func show(displays: [SCDisplay], completion: @escaping (SCDisplay) -> Void) {
        selectionCallback = completion

        guard let screen = NSScreen.main else { return }
        let frame = screen.frame

        let window = NSWindow(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.level = .screenSaver
        window.backgroundColor = .clear
        window.isOpaque = false
        window.ignoresMouseEvents = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let hostingView = NSHostingView(rootView: DisplayPickerView(
            displays: displays.map { d in
                DisplayInfo(
                    id: UUID(),
                    display: d,
                    name: "Display",
                    resolution: "\(Int(d.frame.width)) × \(Int(d.frame.height))"
                )
            },
            onDismiss: { hide() },
            onSelect: { display in
                selectionCallback?(display)
                hide()
            }
        ))
        window.contentView = hostingView
        overlayWindow = window

        window.alphaValue = 0
        window.makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            window.animator().alphaValue = 1
        }
    }

    static func hide() {
        guard let window = overlayWindow else { return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            window.animator().alphaValue = 0
        } completionHandler: {
            window.orderOut(nil)
            overlayWindow = nil
        }
    }
}

struct DisplayPickerView: View {
    let displays: [DisplayInfo]
    let onDismiss: () -> Void
    let onSelect: (SCDisplay) -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Text("Select a display")
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                    Button("Cancel") { onDismiss() }
                        .buttonStyle(.bordered)
                        .tint(.gray)
                }
                .padding()

                VStack(spacing: 12) {
                    ForEach(displays) { display in
                        Button(action: { onSelect(display.display) }) {
                            HStack {
                                Image(systemName: "display")
                                    .font(.system(size: 24))
                                VStack(alignment: .leading) {
                                    Text(display.name)
                                        .font(.system(size: 14, weight: .medium))
                                    Text(display.resolution)
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                            .padding()
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .frame(width: 400)
            .background(Color(NSColor.windowBackgroundColor))
            .cornerRadius(12)
            .shadow(radius: 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(
            Group {
                if #available(macOS 14.0, *) {
                    EmptyView()
                        .onKeyPress(.escape) {
                            onDismiss()
                            return .handled
                        }
                }
            }
        )
    }
}
