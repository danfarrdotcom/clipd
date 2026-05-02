import SwiftUI
import AppKit
import Sparkle

class MenuBarManager: NSObject, ObservableObject {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var captureManager: CaptureManager
    private var hotKeyMonitor: Any?
    private let updater: SPUUpdater?

    init(captureManager: CaptureManager, updater: SPUUpdater? = nil) {
        self.captureManager = captureManager
        self.updater = updater
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
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        let popover = NSPopover()
        popover.contentSize = NSSize(width: 300, height: 320)
        popover.behavior = .transient
        popover.animates = true

        // Pass updater to SwiftUI view
        popover.contentViewController = NSHostingController(
            rootView: RecordingControls()
                .environmentObject(captureManager)
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
        let event = NSApp.currentEvent!

        if event.type == .rightMouseUp {
            showContextMenu()
            return
        }

        if popover?.isShown == true {
            popover?.performClose(nil)
        } else {
            if let button = statusItem?.button {
                popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()

        menu.addItem(NSMenuItem(title: "Record Clip", action: #selector(startRecording), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())

        // Add Sparkle check for updates menu item
        if let updater = updater {
            let updateItem = NSMenuItem(title: "Check for Updates…", action: #selector(checkForUpdates), keyEquivalent: "")
            updateItem.target = self
            menu.addItem(updateItem)
            menu.addItem(NSMenuItem.separator())
        }

        menu.addItem(NSMenuItem(title: "Open Recordings Folder", action: #selector(openRecordingsFolder), keyEquivalent: "o"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }

    @objc private func checkForUpdates() {
        updater?.checkForUpdates()
    }

    @objc private func startRecording() {
        captureManager.startRegionSelection()
    }

    @objc private func openRecordingsFolder() {
        let url = FileManager.default.temporaryDirectory
        NSWorkspace.shared.open(url)
    }

    @objc private func openSettings() {
        NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
    }

    deinit {
        if let monitor = hotKeyMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}
