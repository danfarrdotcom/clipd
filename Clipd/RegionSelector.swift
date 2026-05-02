import SwiftUI
import AppKit

class RegionSelector {
    static var selectionCallback: ((CGRect) -> Void)?
    static var overlayWindow: NSWindow?

    static func show(completion: @escaping (CGRect) -> Void) {
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

        let view = RegionSelectorView(frame: frame)
        window.contentView = view

        overlayWindow = window
        window.makeKeyAndOrderFront(nil)

        // Fade in
        window.alphaValue = 0
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

class RegionSelectorView: NSView {
    private var startPoint: NSPoint?
    private var currentRect: NSRect = .zero
    private var selectionLayer: CAShapeLayer?
    private var instructionLabel: NSTextField?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.35).cgColor

        let label = NSTextField(labelWithString: "Drag to select recording area")
        label.font = .systemFont(ofSize: 18, weight: .medium)
        label.textColor = .white
        label.alignment = .center
        label.frame = NSRect(x: 0, y: bounds.midY - 15, width: bounds.width, height: 30)
        label.autoresizingMask = [.width]
        addSubview(label)
        instructionLabel = label

        // Crosshair cursor
        addCursorRect(bounds, cursor: .crosshair)
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    override func mouseDown(with event: NSEvent) {
        startPoint = convert(event.locationInWindow, from: nil)
        instructionLabel?.isHidden = true

        let layer = CAShapeLayer()
        layer.fillColor = NSColor.systemBlue.withAlphaComponent(0.15).cgColor
        layer.strokeColor = NSColor.systemBlue.cgColor
        layer.lineWidth = 2
        layer.lineDashPattern = [8, 4]
        self.layer?.addSublayer(layer)
        selectionLayer = layer

        // Animated border
        let animation = CABasicAnimation(keyPath: "lineDashPhase")
        animation.fromValue = 0
        animation.toValue = 24
        animation.duration = 0.5
        animation.repeatCount = .infinity
        layer.add(animation, forKey: "dash")
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = startPoint else { return }
        let current = convert(event.locationInWindow, from: nil)

        currentRect = NSRect(
            x: min(start.x, current.x),
            y: min(start.y, current.y),
            width: abs(current.x - start.x),
            height: abs(current.y - start.y)
        )

        let path = CGPath(rect: currentRect, transform: nil)
        selectionLayer?.path = path

        // Update dimensions label
        if let label = instructionLabel {
            label.isHidden = false
            label.stringValue = "\(Int(currentRect.width)) × \(Int(currentRect.height))"
            label.frame.origin = NSPoint(
                x: currentRect.maxX + 8,
                y: currentRect.maxY - 20
            )
        }
    }

    override func mouseUp(with event: NSEvent) {
        guard currentRect.width > 50, currentRect.height > 50 else {
            // Too small, cancel
            RegionSelector.hide()
            return
        }

        RegionSelector.hide()

        // Convert to screen coordinates (flipped Y)
        let screenFrame = NSScreen.main?.frame ?? .zero
        let screenRect = CGRect(
            x: currentRect.origin.x,
            y: screenFrame.height - currentRect.origin.y - currentRect.height,
            width: currentRect.width,
            height: currentRect.height
        )

        RegionSelector.selectionCallback?(screenRect)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape
            RegionSelector.hide()
        }
    }

    override var acceptsFirstResponder: Bool { true }
}
