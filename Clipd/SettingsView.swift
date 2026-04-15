import SwiftUI

struct SettingsView: View {
    @AppStorage("fps") private var fps: Double = 15
    @AppStorage("includeCursor") private var includeCursor: Bool = true

    var body: some View {
        TabView {
            generalSettings
                .tabItem { Label("General", systemImage: "gear") }
            aboutView
                .tabItem { Label("About", systemImage: "info.circle") }
        }
    }

    private var generalSettings: some View {
        Form {
            Slider(value: $fps, in: 5...30, step: 5) {
                Text("Frame Rate: \(Int(fps)) FPS")
            }
            Toggle("Include cursor in recording", isOn: $includeCursor)
        }
        .padding()
        .frame(width: 350)
    }

    private var aboutView: some View {
        VStack(spacing: 8) {
            Text("Clipd")
                .font(.title)
            Text("Version 0.1")
                .foregroundColor(.secondary)
            Text("A lightweight screen recorder for macOS")
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(width: 350)
    }
}
