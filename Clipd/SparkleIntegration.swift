import SwiftUI
import Sparkle

// MARK: - Sparkle Updater Integration
// Sparkle 2 provides automatic software updates for macOS apps [^50^]

final class UpdaterViewModel: ObservableObject {
    @Published var canCheckForUpdates = false

    init(updater: SPUUpdater) {
        updater.publisher(for: \ .canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }
}

struct CheckForUpdatesView: View {
    @ObservedObject private var viewModel: UpdaterViewModel
    private let updater: SPUUpdater

    init(updater: SPUUpdater) {
        self.updater = updater
        self.viewModel = UpdaterViewModel(updater: updater)
    }

    var body: some View {
        Button("Check for Updates…", action: updater.checkForUpdates)
            .disabled(!viewModel.canCheckForUpdates)
    }
}

// MARK: - Extended App Delegate with Sparkle
class AppDelegateWithSparkle: NSObject, NSApplicationDelegate, ObservableObject {
    var captureManager = CaptureManager()
    var menuBarManager: MenuBarManager?

    // Sparkle updater controller [^48^]
    private let updaterController: SPUStandardUpdaterController

    override init() {
        // Initialize Sparkle updater
        // Set SUFeedURL in Info.plist to point to your appcast.xml
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        super.init()
    }

    var updater: SPUUpdater {
        updaterController.updater
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBarManager = MenuBarManager(captureManager: captureManager, updater: updater)
        NSApp.setActivationPolicy(.accessory)

        // Optional: Check for updates on launch (respects user preferences)
        // updater.checkForUpdatesInBackground()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}
