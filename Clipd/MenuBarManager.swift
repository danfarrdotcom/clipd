import SwiftUI
import AppKit

class MenuBarManager: NSObject, ObservableObject {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var captureManager: CaptureManager
    private var hotKeyMonitor: Any?

    init(captureManager: CaptureManager) {
        self.captureManager = captureManager
        super.init()
        setupMenuBar()
        setupHotKey()
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "record.circle", accessibilityDescription: "Clipd")
            button.action = #selector(togglePopover)
            button.target = self
        }

        let popover = NSPopover()
        popover.contentSize = NSSize(width: 300, height: 200)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: RecordingControls()
        )
        self.popover = popover
    }

    private func setupHotKey() {
        hotKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.modifierFlags.contains([.command, .shift]),
                  event.keyCode == 5 else { return }
            self?.captureManager.startRegionSelection()
        }
    }

    @objc private func togglePopover(_ sender: NSStatusBarButton) {
        if popover?.isShown == true {
            popover?.performClose(nil)
        } else {
            if let button = statusItem?.button {
                popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }

    deinit {
        if let monitor = hotKeyMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}
