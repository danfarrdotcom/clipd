import SwiftUI

struct SettingsView: View {
    @AppStorage("defaultFPS") private var defaultFPS: Double = 15.0
    @AppStorage("optimizeGIF") private var optimizeGIF: Bool = true
    @AppStorage("showCursor") private var showCursor: Bool = true
    @AppStorage("autoCopy") private var autoCopy: Bool = false
    @AppStorage("saveLocation") private var saveLocation: String = ""
    @AppStorage("defaultFormat") private var defaultFormat: String = "gif"
    @AppStorage("defaultSource") private var defaultSource: String = "region"
    @AppStorage("backgroundStyle") private var backgroundStyle: String = "none"
    @AppStorage("chromeType") private var chromeType: String = "none"
    @AppStorage("solidColorRGBA") private var solidColorRGBA: String = "0.68,0.68,0.70,1.0"
    @AppStorage("gradientTopRGBA") private var gradientTopRGBA: String = "0.68,0.68,0.70,1.0"
    @AppStorage("gradientBottomRGBA") private var gradientBottomRGBA: String = "0.58,0.58,0.60,1.0"

    var body: some View {
        TabView {
            generalSettings
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            shortcutSettings
                .tabItem {
                    Label("Shortcuts", systemImage: "keyboard")
                }

            aboutView
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }

            backgroundChromeSettings
                .tabItem {
                    Label("Style", systemImage: "paintpalette")
                }
        }
        .frame(width: 450, height: 350)
        .padding()
    }

    private var generalSettings: some View {
        Form {
            Section("Recording") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Default FPS: \(Int(defaultFPS))")
                        .font(.system(size: 13))
                    Slider(value: $defaultFPS, in: 5...30, step: 1)
                }

                Toggle("Show cursor in recordings", isOn: $showCursor)

                Picker("Default source", selection: $defaultSource) {
                    ForEach(RecordingSource.allCases) { source in
                        Label(source.label, systemImage: source.icon)
                            .tag(source.rawValue)
                    }
                }
            }

            Section("Output") {
                Toggle("Auto-copy to clipboard", isOn: $autoCopy)

                Picker("Default format", selection: $defaultFormat) {
                    ForEach(OutputFormat.allCases) { format in
                        Text(format.rawValue).tag(format.rawValue)
                    }
                }

                HStack {
                    Text("Save location:")
                    Spacer()
                    if saveLocation.isEmpty {
                        Text("Temporary folder")
                            .foregroundColor(.secondary)
                    } else {
                        Text(saveLocation)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    Button("Choose...") {
                        chooseSaveLocation()
                    }
                    .controlSize(.small)
                }
            }
        }
        .formStyle(.grouped)
    }

    private var shortcutSettings: some View {
        Form {
            Section("Global Shortcuts") {
                HStack {
                    Text("Quick Record")
                    Spacer()
                    KeyboardShortcutView(keys: ["⌘", "⇧", "4"])
                }

                HStack {
                    Text("Stop Recording")
                    Spacer()
                    KeyboardShortcutView(keys: ["⌘", "⇧", "5"])
                }
            }

            Text("Shortcuts work even when the app is not focused.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .formStyle(.grouped)
    }

    private var aboutView: some View {
        VStack(spacing: 16) {
            Image(systemName: "record.circle")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)

            Text("Clipd")
                .font(.system(size: 20, weight: .bold))

            Text("Version 1.0")
                .font(.caption)
                .foregroundColor(.secondary)

            Text("A lightweight screen recorder for creating GIFs and videos.")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding()
    }

    private var backgroundChromeSettings: some View {
        Form {
            Section("Background") {
                Picker("Style", selection: $backgroundStyle) {
                    ForEach(BackgroundStyle.allCases) { style in
                        Text(style.rawValue).tag(style.rawValue)
                    }
                }

                if backgroundStyle == "Solid Color" {
                    ColorPicker("Color", selection: solidColorBinding)
                }

                if backgroundStyle == "Gradient" {
                    ColorPicker("Top color", selection: gradientTopBinding)
                    ColorPicker("Bottom color", selection: gradientBottomBinding)
                }
            }

            Section("Chrome Overlay") {
                Picker("Type", selection: $chromeType) {
                    ForEach(ChromeType.allCases) { chrome in
                        Label(chrome.rawValue, systemImage: chrome.icon)
                            .tag(chrome.rawValue)
                    }
                }

                if chromeType != "None" {
                    Text("Output: \(chromeOutputDimensions)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Section("Note") {
                Text("Background and chrome are applied after recording stops. This may add a few seconds to processing time.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private var chromeOutputDimensions: String {
        let chrome = ChromeType(rawValue: chromeType) ?? .none
        let size = chrome.outputSize
        if size.width == 0 {
            return "Matches recording size"
        }
        return "\(Int(size.width)) × \(Int(size.height))"
    }

    private var solidColorBinding: Binding<Color> {
        Binding(
            get: { rgbaToColor(solidColorRGBA) },
            set: { solidColorRGBA = colorToRGBA($0) }
        )
    }

    private var gradientTopBinding: Binding<Color> {
        Binding(
            get: { rgbaToColor(gradientTopRGBA) },
            set: { gradientTopRGBA = colorToRGBA($0) }
        )
    }

    private var gradientBottomBinding: Binding<Color> {
        Binding(
            get: { rgbaToColor(gradientBottomRGBA) },
            set: { gradientBottomRGBA = colorToRGBA($0) }
        )
    }

    private func rgbaToColor(_ rgba: String) -> Color {
        let components = rgba.split(separator: ",").compactMap { Double($0) }
        guard components.count == 4 else { return .gray }
        return Color(
            red: components[0],
            green: components[1],
            blue: components[2],
            opacity: components[3]
        )
    }

    private func colorToRGBA(_ color: Color) -> String {
        let nsColor = NSColor(color)
        let red = CGFloat(nsColor.redComponent)
        let green = CGFloat(nsColor.greenComponent)
        let blue = CGFloat(nsColor.blueComponent)
        let alpha = CGFloat(nsColor.alphaComponent)
        return "\(red),\(green),\(blue),\(alpha)"
    }

    private func chooseSaveLocation() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Select"

        if panel.runModal() == .OK {
            saveLocation = panel.url?.path ?? ""
        }
    }
}

struct KeyboardShortcutView: View {
    let keys: [String]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(keys, id: \.self) { key in
                Text(key)
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(NSColor.controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .cornerRadius(4)
            }
        }
    }
}
