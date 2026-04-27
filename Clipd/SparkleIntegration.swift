import SwiftUI
import Sparkle

final class UpdaterViewModel: ObservableObject {
    @Published var canCheckForUpdates = false

    init(updater: SPUUpdater) {
        updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }
}

struct CheckForUpdatesView: View {
    @ObservedObject private var updaterViewModel: UpdaterViewModel
    private let updater: SPUUpdater

    init(updater: SPUUpdater) {
        self.updater = updater
        self.updaterViewModel = UpdaterViewModel(updater: updater)
    }

    var body: some View {
        Button("Check for Updates…", action: updater.checkForUpdates)
            .disabled(!updaterViewModel.canCheckForUpdates)
    }
}

class AppDelegateWithSparkle: NSObject, NSApplicationDelegate {
    private var updaterController: SPUStandardUpdaterController!
    private var captureManager: CaptureManager!
    private var menuBarManager: MenuBarManager!

    override init() {
        updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        captureManager = CaptureManager()
        menuBarManager = MenuBarManager(captureManager: captureManager, updater: updaterController.updater)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
