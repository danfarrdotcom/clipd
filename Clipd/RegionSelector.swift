import AppKit

class RegionSelector {
    static private var window: NSWindow?
    static private var completion: ((CGRect) -> Void)?

    static func show(completion: @escaping (CGRect) -> Void) {
        self.completion = completion
        let frame = NSScreen.main!.frame
        let view = RegionSelectorView(frame: frame)
        window = NSWindow(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        window?.level = .screenSaver
        window?.isOpaque = false
        window?.backgroundColor = NSColor.black.withAlphaComponent(0.3)
        window?.contentView = view
        window?.orderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    static func hide() {
        window?.orderOut(nil)
        window = nil
    }
}

class RegionSelectorView: NSView {
    private var startPoint: CGPoint?
    private var currentRect: CGRect = .zero
    private let overlayView = NSView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(overlayView)
        overlayView.wantsLayer = true
        overlayView.layer?.borderWidth = 2
        overlayView.layer?.borderColor = NSColor.systemBlue.cgColor
    }

    required init?(coder: NSCoder) { fatalError() }

    override func mouseDown(with event: NSEvent) {
        startPoint = convert(event.locationInWindow, from: nil)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = startPoint else { return }
        let current = convert(event.locationInWindow, from: nil)
        currentRect = CGRect(x: min(start.x, current.x), y: min(start.y, current.y),
                             width: abs(current.x - start.x), height: abs(current.y - start.y))
        overlayView.frame = currentRect
    }

    override func mouseUp(with event: NSEvent) {
        guard currentRect.width > 10 && currentRect.height > 10 else { return }
        RegionSelector.hide()
        let screenRect = convertToScreen(currentRect)
        RegionSelector.completion?(screenRect)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { RegionSelector.hide() }
    }

    private func convertToScreen(_ rect: CGRect) -> CGRect {
        guard let screen = NSScreen.main else { return rect }
        return CGRect(x: rect.origin.x, y: screen.frame.height - rect.origin.y - rect.height,
                      width: rect.width, height: rect.height)
    }
}
