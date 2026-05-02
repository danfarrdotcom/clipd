import AppKit
import CoreGraphics
import CoreImage
import AVFoundation

enum BackgroundStyle: String, CaseIterable, Identifiable {
    case none = "None"
    case solidColor = "Solid Color"
    case gradient = "Gradient"
    case transparent = "Transparent"

    var id: String { rawValue }
}

enum ChromeType: String, CaseIterable, Identifiable {
    case none = "None"
    case macOSWindow = "macOS Window"
    case roundedCorners = "Rounded Corners"
    case iPhone = "iPhone Frame"
    case macbook = "MacBook Frame"

    var id: String { rawValue }

    var outputSize: CGSize {
        switch self {
        case .none: return CGSize(width: 0, height: 0)
        case .macOSWindow: return CGSize(width: 1280, height: 800)
        case .roundedCorners: return CGSize(width: 0, height: 0)
        case .iPhone: return CGSize(width: 828, height: 1792)
        case .macbook: return CGSize(width: 1680, height: 1050)
        }
    }

    var icon: String {
        switch self {
        case .none: return "nosign"
        case .macOSWindow: return "macwindow"
        case .roundedCorners: return "rectangle.roundedtop"
        case .iPhone: return "iphone"
        case .macbook: return "laptopcomputer"
        }
    }
}

class FrameCompositor {
    var backgroundStyle: BackgroundStyle = .none
    var chromeType: ChromeType = .none
    var solidColor: CGColor = NSColor.systemGray.cgColor ?? CGColor.gray
    var gradientTop: CGColor = NSColor.systemGray.cgColor ?? CGColor.gray
    var gradientBottom: CGColor = NSColor.systemGray2.cgColor ?? CGColor.lightGray

    func outputSize(for originalSize: CGSize) -> CGSize {
        let chromeSize = chromeType.outputSize
        if chromeSize.width == 0 || chromeSize.height == 0 {
            return originalSize
        }
        return chromeSize
    }

    func contentRect(for outputSize: CGSize, originalSize: CGSize) -> CGRect {
        let scale = min(outputSize.width / originalSize.width, outputSize.height / originalSize.height)
        let scaledWidth = originalSize.width * scale
        let scaledHeight = originalSize.height * scale
        let x = (outputSize.width - scaledWidth) / 2
        let y = (outputSize.height - scaledHeight) / 2
        return CGRect(x: x, y: y, width: scaledWidth, height: scaledHeight)
    }

    func compose(frame: CGImage, originalSize: CGSize) -> CGImage? {
        if chromeType == .roundedCorners {
            return composeRoundedCorners(frame: frame, originalSize: originalSize)
        }

        let outSize = outputSize(for: originalSize)
        guard let context = CGContext(
            data: nil,
            width: Int(outSize.width),
            height: Int(outSize.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        switch backgroundStyle {
        case .none:
            context.setFillColor(.white)
            context.fill(CGRect(origin: .zero, size: outSize))
        case .solidColor:
            context.setFillColor(solidColor)
            context.fill(CGRect(origin: .zero, size: outSize))
        case .gradient:
            drawGradient(in: CGRect(origin: .zero, size: outSize), context: context)
        case .transparent:
            break
        }

        let rect = contentRect(for: outSize, originalSize: originalSize)
        context.interpolationQuality = .high
        context.draw(frame, in: rect)

        drawChromeOverlay(into: context, outputSize: outSize, originalSize: originalSize)

        return context.makeImage()
    }

    private func composeRoundedCorners(frame: CGImage, originalSize: CGSize) -> CGImage? {
        let cornerRadius: CGFloat = 20
        let shadowOffset: CGFloat = 8
        let padding: CGFloat = 20

        let canvasSize = CGSize(width: originalSize.width + padding * 2, height: originalSize.height + padding * 2)

        guard let context = CGContext(
            data: nil,
            width: Int(canvasSize.width),
            height: Int(canvasSize.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        switch backgroundStyle {
        case .solidColor:
            context.setFillColor(solidColor)
            context.fill(CGRect(origin: .zero, size: canvasSize))
        case .gradient:
            drawGradient(in: CGRect(origin: .zero, size: canvasSize), context: context)
        case .none, .transparent:
            break
        }

        let rect = CGRect(x: padding, y: padding, width: originalSize.width, height: originalSize.height)
        let path = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)

        context.setShadow(offset: CGSize(width: 0, height: -shadowOffset), blur: shadowOffset, color: CGColor(space: CGColorSpaceCreateDeviceRGB(), components: [0, 0, 0, 0.3])!)

        context.addPath(path)
        context.clip()

        context.interpolationQuality = .high
        context.draw(frame, in: rect)

        return context.makeImage()
    }

    private func drawGradient(in rect: CGRect, context: CGContext) {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let colors = [gradientTop, gradientBottom] as CFArray
        guard let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0.0, 1.0]) else { return }

        let startPoint = CGPoint(x: rect.midX, y: rect.maxY)
        let endPoint = CGPoint(x: rect.midX, y: rect.minY)
        context.drawLinearGradient(gradient, start: startPoint, end: endPoint, options: [])
    }

    private func drawChromeOverlay(into context: CGContext, outputSize: CGSize, originalSize: CGSize) {
        switch chromeType {
        case .none:
            break
        case .roundedCorners:
            break
        case .macOSWindow:
            drawMacOSWindowChrome(into: context, outputSize: outputSize)
        case .iPhone:
            drawDeviceFrameOverlay(named: "iphone-frame", into: context, outputSize: outputSize)
        case .macbook:
            drawDeviceFrameOverlay(named: "macbook-frame", into: context, outputSize: outputSize)
        }
    }

    private func drawMacOSWindowChrome(into context: CGContext, outputSize: CGSize) {
        let titleBarHeight: CGFloat = 38
        let titleBarRect = CGRect(x: 0, y: 0, width: outputSize.width, height: titleBarHeight)
        context.setFillColor(NSColor.windowBackgroundColor.cgColor ?? CGColor.gray)
        context.fill(titleBarRect)

        context.setStrokeColor(NSColor.separatorColor.cgColor ?? CGColor.gray)
        context.setLineWidth(1)
        context.beginPath()
        context.move(to: CGPoint(x: 0, y: titleBarHeight))
        context.addLine(to: CGPoint(x: outputSize.width, y: titleBarHeight))
        context.strokePath()

        context.setStrokeColor(NSColor.separatorColor.cgColor ?? CGColor.gray)
        context.setLineWidth(1)
        let borderRect = CGRect(x: 0.5, y: 0.5, width: outputSize.width - 1, height: outputSize.height - 1)
        context.addRect(borderRect)
        context.strokePath()

        let dotRadius: CGFloat = 6
        let dotY: CGFloat = titleBarHeight / 2
        let dotSpacing: CGFloat = 16
        let startX: CGFloat = 14

        let colors: [CGColor] = [
            NSColor(red: 0.96, green: 0.35, blue: 0.20, alpha: 1.0).cgColor ?? CGColor.red,
            NSColor(red: 0.97, green: 0.72, blue: 0.15, alpha: 1.0).cgColor ?? CGColor.yellow,
            NSColor(red: 0.19, green: 0.72, blue: 0.15, alpha: 1.0).cgColor ?? CGColor.green,
        ]

        for (i, color) in colors.enumerated() {
            let dotX = startX + CGFloat(i) * dotSpacing
            let dotRect = CGRect(x: dotX - dotRadius, y: dotY - dotRadius, width: dotRadius * 2, height: dotRadius * 2)
            context.setFillColor(color)
            context.fillEllipse(in: dotRect)
        }
    }

    private func drawDeviceFrameOverlay(named resourceName: String, into context: CGContext, outputSize: CGSize) {
        guard let url = Bundle.main.url(forResource: resourceName, withExtension: "png", subdirectory: "Chrome"),
              let nsImage = NSImage(contentsOf: url),
              let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return
        }
        let frameRect = CGRect(origin: .zero, size: outputSize)
        context.interpolationQuality = .high
        context.draw(cgImage, in: frameRect)
    }

    func compose(sampleBuffer: CMSampleBuffer, originalSize: CGSize) -> CMSampleBuffer? {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }

        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        let ciContext = CIContext(options: nil)
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else { return nil }

        guard let composedImage = compose(frame: cgImage, originalSize: originalSize) else { return nil }

        let outSize = outputSize(for: originalSize)
        return createSampleBuffer(from: composedImage, size: outSize, timingInfo: sampleBuffer)
    }

    private func createSampleBuffer(from image: CGImage, size: CGSize, timingInfo: CMSampleBuffer) -> CMSampleBuffer? {
        var pixelBuffer: CVPixelBuffer?
        let attributes: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]

        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(size.width),
            Int(size.height),
            kCVPixelFormatType_32BGRA,
            attributes as CFDictionary,
            &pixelBuffer
        )

        guard status == kCVReturnSuccess, let buffer = pixelBuffer else { return nil }

        CVPixelBufferLockBaseAddress(buffer, [])
        let baseAddress = CVPixelBufferGetBaseAddress(buffer)!
        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)

        guard let context = CGContext(
            data: baseAddress,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else {
            CVPixelBufferUnlockBaseAddress(buffer, [])
            return nil
        }

        context.draw(image, in: CGRect(origin: .zero, size: size))
        CVPixelBufferUnlockBaseAddress(buffer, [])

        var formatDescription: CMFormatDescription?
        CMVideoFormatDescriptionCreate(
            allocator: kCFAllocatorDefault,
            codecType: kCMVideoCodecType_H264,
            width: Int32(size.width),
            height: Int32(size.height),
            extensionDictionary: nil,
            formatDescriptionOut: &formatDescription
        )

        guard let format = formatDescription else { return nil }

        var newSampleBuffer: CMSampleBuffer?
        var timing = CMSampleTimingInfo(
            duration: CMSampleBufferGetDuration(timingInfo),
            presentationTimeStamp: CMSampleBufferGetPresentationTimeStamp(timingInfo),
            decodeTimeStamp: CMSampleBufferGetDecodeTimeStamp(timingInfo)
        )

        CMSampleBufferCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: buffer,
            dataReady: true,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: format,
            sampleTiming: &timing,
            sampleBufferOut: &newSampleBuffer
        )

        return newSampleBuffer
    }
}
