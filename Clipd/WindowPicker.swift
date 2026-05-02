import SwiftUI
import AppKit
import ScreenCaptureKit

struct WindowPickerItem: Identifiable {
    let id: CGWindowID
    let window: SCWindow
    let appName: String
    let thumbnail: NSImage?
    
    var itemName: String {
        window.title ?? "Untitled"
    }
}

class WindowPicker {
    static var selectionCallback: ((SCWindow) -> Void)?
    static var overlayWindow: NSWindow?

    @MainActor
    static func show(completion: @escaping (SCWindow) -> Void) {
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

        let hostingView = NSHostingView(rootView: WindowPickerView(
            onDismiss: { hide() },
            onSelect: { window in
                selectionCallback?(window)
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

struct WindowPickerView: View {
    let onDismiss: () -> Void
    let onSelect: (SCWindow) -> Void
    @State private var windows: [WindowPickerItem] = []
    @State private var loading = true

    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()

            if loading {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Loading windows...")
                        .foregroundColor(.white)
                }
            } else if windows.isEmpty {
                Text("No windows available")
                    .foregroundColor(.white)
                    .font(.headline)
            } else {
                VStack(spacing: 0) {
                    HStack {
                        Text("Select a window to record")
                            .font(.headline)
                            .foregroundColor(.white)
                        Spacer()
                        Button("Cancel") {
                            onDismiss()
                        }
                        .buttonStyle(.bordered)
                        .tint(.gray)
                    }
                    .padding()

                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 180, maximum: 220), spacing: 16)], spacing: 16) {
                            ForEach(windows) { item in
                                WindowCard(item: item) {
                                    onSelect(item.window)
                                }
                            }
                        }
                        .padding()
                    }
                }
                .padding(.top)
                .frame(width: 800, height: 500)
                .background(Color(NSColor.windowBackgroundColor))
                .cornerRadius(12)
                .shadow(radius: 20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            await loadWindows()
        }
        .onKeyPress(.escape) {
            onDismiss()
            return .handled
        }
    }

    @MainActor
    private func loadWindows() async {
        do {
            let content = try await SCShareableContent.current
            let systemBundleIDs = Set(["com.apple.dock", "com.apple.WindowManager", "com.apple.finder"])

            var items: [WindowPickerItem] = []
            for window in content.windows {
                guard let app = window.owningApplication,
                      !systemBundleIDs.contains(app.bundleIdentifier),
                      window.isOnScreen,
                      window.frame.width > 100,
                      window.frame.height > 100,
                      !(window.title?.isEmpty ?? true) else { continue }

                let thumbnail = window.image.flatMap { image in
                    NSImage(cgImage: image, size: NSSize(width: window.frame.width, height: window.frame.height))
                }

                items.append(WindowPickerItem(
                    id: window.windowID,
                    window: window,
                    appName: app.applicationName,
                    thumbnail: thumbnail
                ))
            }

            windows = items.sorted { $0.appName < $1.appName }
            loading = false
        } catch {
            print("Failed to load windows: \(error)")
            loading = false
        }
    }
}

struct WindowCard: View {
    let item: WindowPickerItem
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                if let thumb = item.thumbnail {
                    Image(nsImage: thumb)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 100)
                        .cornerRadius(6)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 100)
                        .overlay(
                            Image(systemName: "macwindow")
                                .font(.system(size: 32))
                                .foregroundColor(.secondary)
                        )
                        .cornerRadius(6)
                }

                VStack(spacing: 2) {
                    Text(item.itemName)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                    Text(item.appName)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            .padding(8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}
