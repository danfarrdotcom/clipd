import SwiftUI

// MARK: - Sparkle Updater Integration (stub - add Sparkle SPM package to enable)
// Sparkle 2 provides automatic software updates for macOS apps
// To enable: Add Sparkle via Swift Package Manager (https://github.com/sparkle-project/Sparkle)

final class UpdaterViewModel: ObservableObject {
    @Published var canCheckForUpdates = false
}

struct CheckForUpdatesView: View {
    var body: some View {
        Text("Updates")
    }
}

// MARK: - App Delegate (without Sparkle)
@MainActor
class AppDelegateWithSparkle: NSObject, NSApplicationDelegate, ObservableObject {
    var captureManager = CaptureManager()
    var menuBarManager: MenuBarManager?

    override init() {
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBarManager = MenuBarManager(captureManager: captureManager)
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}
