import SwiftUI

struct SettingsView: View {
    @AppStorage("fps") private var fps: Double = 15
    @AppStorage("includeCursor") private var includeCursor: Bool = true
    @AppStorage("defaultFormat") private var defaultFormat: String = "gif"

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
            Picker("Output Format", selection: $defaultFormat) {
                Text("GIF").tag("gif")
            }

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
            Text("Version 0.2")
                .foregroundColor(.secondary)
            Text("A lightweight screen recorder for creating GIFs and videos.")
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(width: 350)
    }
}
