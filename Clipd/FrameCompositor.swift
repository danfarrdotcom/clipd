import AppKit

enum BackgroundStyle: String, CaseIterable, Identifiable {
    case none, solid, gradient, transparent, roundedCorners

    var id: String { rawValue }
    var label: String {
        switch self {
        case .none: return "None"
        case .solid: return "Solid Color"
        case .gradient: return "Gradient"
        case .transparent: return "Transparent"
        case .roundedCorners: return "Rounded Corners"
        }
    }
}

enum ChromeType: String, CaseIterable, Identifiable {
    case none, macOSWindow, iphone, macbook

    var id: String { rawValue }
    var label: String {
        switch self {
        case .none: return "None"
        case .macOSWindow: return "macOS Window"
        case .iphone: return "iPhone"
        case .macbook: return "MacBook"
        }
    }
}

class FrameCompositor {
    private let backgroundStyle: BackgroundStyle
    private let chromeType: ChromeType
    private let solidColor: NSColor
    private let gradientStart: NSColor
    private let gradientEnd: NSColor

    init(backgroundStyle: BackgroundStyle = .none,
         chromeType: ChromeType = .none,
         solidColor: NSColor = .white,
         gradientStart: NSColor = NSColor(red: 0.4, green: 0.6, blue: 1.0, alpha: 1),
         gradientEnd: NSColor = NSColor(red: 0.8, green: 0.4, blue: 1.0, alpha: 1)) {
        self.backgroundStyle = backgroundStyle
        self.chromeType = chromeType
        self.solidColor = solidColor
        self.gradientStart = gradientStart
        self.gradientEnd = gradientEnd
    }

    func outputSize(for originalSize: CGSize) -> CGSize {
        switch chromeType {
        case .none, .macOSWindow, .roundedCorners: return originalSize
        case .iphone: return CGSize(width: 828, height: 1792)
        case .macbook: return CGSize(width: 1680, height: 1050)
        }
    }

    func compose(frame: CGImage, originalSize: CGSize) -> CGImage? {
        let outputSize = self.outputSize(for: originalSize)
        let context = CGContext(data: nil,
                                width: Int(outputSize.width),
                                height: Int(outputSize.height),
                                bitsPerComponent: 8,
                                bytesPerRow: 0,
                                space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        guard let ctx = context else { return nil }

        ctx.setAllowsAntialiasing(true)
        ctx.setShouldAntialias(true)

        // Draw background
        switch backgroundStyle {
        case .none: break
        case .solid:
            solidColor.setFill()
            ctx.fill(CGRect(origin: .zero, size: outputSize))
        case .gradient:
            drawGradient(in: CGRect(origin: .zero, size: outputSize), context: ctx)
        case .transparent: break
        case .roundedCorners:
            return composeRoundedCorners(frame: frame, originalSize: originalSize)
        }

        // Draw frame content
        let contentRect = contentRect(for: outputSize, originalSize: originalSize)
        ctx.draw(frame, in: contentRect)

        // Draw chrome overlay
        drawChromeOverlay(into: outputSize, originalSize: originalSize, context: ctx)

        return ctx.makeImage()
    }

    private func composeRoundedCorners(frame: CGImage, originalSize: CGSize) -> CGImage? {
        let padding: CGFloat = 20
        let cornerRadius: CGFloat = 16
        let size = CGSize(width: originalSize.width + padding * 2, height: originalSize.height + padding * 2)

        guard let ctx = CGContext(data: nil, width: Int(size.width), height: Int(size.height),
                                  bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }

        ctx.setAllowsAntialiasing(true)
        ctx.setShouldAntialias(true)

        // Shadow
        ctx.setShadow(offset: CGSize(width: 0, height: 8), blur: 20, color: NSColor.black.withAlphaComponent(0.3).cgColor)

        // Background with rounded corners
        let rect = CGRect(x: padding/2, y: padding/2, width: originalSize.width, height: originalSize.height)
        let path = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
        ctx.addPath(path)
        ctx.clip()

        ctx.draw(frame, in: rect)

        // Border
        ctx.setShadow(offset: .zero, blur: 0)
        ctx.setStrokeColor(NSColor.systemGray.cgColor)
        ctx.setLineWidth(1)
        ctx.addPath(path)
        ctx.strokePath()

        return ctx.makeImage()
    }

    private func drawGradient(in rect: CGRect, context: CGContext) {
        let gradient = CGGradient(colorsSpace: nil, colors: [gradientStart.cgColor, gradientEnd.cgColor] as CFArray, locations: [0.0, 1.0])!
        context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 0), end: CGPoint(x: rect.width, y: rect.height), options: [])
    }

    private func contentRect(for outputSize: CGSize, originalSize: CGSize) -> CGRect {
        let scaleX = outputSize.width / originalSize.width
        let scaleY = outputSize.height / originalSize.height
        let scale = min(scaleX, scaleY)
        let w = originalSize.width * scale
        let h = originalSize.height * scale
        return CGRect(x: (outputSize.width - w) / 2, y: (outputSize.height - h) / 2, width: w, height: h)
    }

    private func drawChromeOverlay(into outputSize: CGSize, originalSize: CGSize, context: CGContext) {
        switch chromeType {
        case .none: break
        case .macOSWindow: drawMacOSWindowChrome(into: outputSize, context: context)
        case .iphone, .macbook: drawDeviceFrameOverlay(named: chromeType.rawValue, into: outputSize, context: context)
        }
    }

    private func drawMacOSWindowChrome(into outputSize: CGSize, context: CGContext) {
        let titleBarHeight: CGFloat = 28
        let rect = CGRect(x: 0, y: outputSize.height - titleBarHeight, width: outputSize.width, height: titleBarHeight)

        // Title bar
        context.setFillColor(NSColor.windowBackgroundColor.cgColor)
        context.fill(rect)

        // Border
        context.setStrokeColor(NSColor.separatorColor.cgColor)
        context.setLineWidth(1)
        context.stroke(CGRect(x: 0, y: 0, width: outputSize.width, height: outputSize.height))

        // Traffic lights
        let colors: [NSColor] = [.systemRed, .systemYellow, .systemGreen]
        for (i, color) in colors.enumerated() {
            let circleRect = CGRect(x: 14 + CGFloat(i) * 18, y: outputSize.height - titleBarHeight + 7, width: 12, height: 12)
            color.setFill()
            context.fillEllipse(in: circleRect)
        }
    }

    private func drawDeviceFrameOverlay(named name: String, into outputSize: CGSize, context: CGContext) {
        guard let image = NSImage(named: "\(name)-frame") else { return }
        let rect = CGRect(origin: .zero, size: outputSize)
        image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1.0)
    }
}
