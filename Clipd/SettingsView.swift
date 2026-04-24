import SwiftUI

struct SettingsView: View {
    @AppStorage("fps") private var fps: Double = 15
    @AppStorage("includeCursor") private var includeCursor: Bool = true
    @AppStorage("defaultFormat") private var defaultFormat: String = "gif"
    @AppStorage("backgroundStyle") private var backgroundStyle: String = "none"
    @AppStorage("chromeType") private var chromeType: String = "none"
    @AppStorage("gradientStart") private var gradientStart: String = "#6699ff"
    @AppStorage("gradientEnd") private var gradientEnd: String = "#cc66ff"

    var body: some View {
        TabView {
            generalSettings
                .tabItem { Label("General", systemImage: "gear") }
            backgroundChromeSettings
                .tabItem { Label("Style", systemImage: "paintpalette") }
            shortcutSettings
                .tabItem { Label("Shortcuts", systemImage: "keyboard") }
            aboutView
                .tabItem { Label("About", systemImage: "info.circle") }
        }
    }

    private var generalSettings: some View {
        Form {
            Picker("Output Format", selection: $defaultFormat) {
                Text("GIF").tag("gif")
                Text("MP4").tag("mp4")
            }
            Slider(value: $fps, in: 5...30, step: 5) {
                Text("Frame Rate: \(Int(fps)) FPS")
            }
            Toggle("Include cursor in recording", isOn: $includeCursor)
        }
        .padding()
        .frame(width: 350)
    }

    private var backgroundChromeSettings: some View {
        Form {
            Picker("Background", selection: $backgroundStyle) {
                ForEach(BackgroundStyle.allCases) { style in
                    Text(style.label).tag(style.rawValue)
                }
            }
            Picker("Chrome", selection: $chromeType) {
                ForEach(ChromeType.allCases) { type in
                    Text(type.label).tag(type.rawValue)
                }
            }
        }
        .padding()
        .frame(width: 350)
    }

    private var shortcutSettings: some View {
        VStack(spacing: 16) {
            shortcutRow(label: "Start recording", keys: ["⌘", "⇧", "4"])
        }
        .padding()
        .frame(width: 350)
    }

    private func shortcutRow(label: String, keys: [String]) -> some View {
        HStack {
            Text(label)
            Spacer()
            KeyboardShortcutView(keys: keys)
        }
    }

    private var aboutView: some View {
        VStack(spacing: 8) {
            Text("Clipd")
                .font(.title)
            Text("Version 0.3")
                .foregroundColor(.secondary)
            Text("A lightweight screen recorder for creating GIFs and videos.")
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(width: 350)
    }
}

struct KeyboardShortcutView: View {
    let keys: [String]
    var body: some View {
        HStack(spacing: 2) {
            ForEach(keys.indices, id: \.self) { i in
                Text(keys[i])
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color(.controlBackgroundColor))
                    .cornerRadius(4)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.gray.opacity(0.3), lineWidth: 0.5))
            }
        }
    }
}
