import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let canvas = 1024

func color(hex: UInt32, alpha: CGFloat = 1) -> CGColor {
    let components: [CGFloat] = [
        CGFloat((hex >> 16) & 0xFF) / 255,
        CGFloat((hex >> 8) & 0xFF) / 255,
        CGFloat(hex & 0xFF) / 255,
        alpha,
    ]
    guard let color = CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: components) else {
        fputs("Не удалось собрать цвет\n", stderr)
        exit(1)
    }
    return color
}

struct Segment {
    var fraction: CGFloat
    var fill: CGColor
    var struck: Bool = false
}

func projectRoot() -> URL {
    let fileManager = FileManager.default
    let current = URL(fileURLWithPath: fileManager.currentDirectoryPath)
    let marker = "test/Assets.xcassets/AppIcon.appiconset"
    if fileManager.fileExists(atPath: current.appendingPathComponent(marker).path) {
        return current
    }
    let script = URL(fileURLWithPath: CommandLine.arguments[0]).resolvingSymlinksInPath()
    return script.deletingLastPathComponent().deletingLastPathComponent()
}

func fillCapsule(_ rect: CGRect, fill: CGColor, in context: CGContext) {
    let radius = rect.height / 2
    let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
    context.addPath(path)
    context.setFillColor(fill)
    context.fillPath()
}

func drawIcon(in context: CGContext) {
    let side = CGFloat(canvas)
    let blue = color(hex: 0x3B82F6)
    let indigo = color(hex: 0x4F46E5)
    let paper = color(hex: 0xFFFFFF)
    let lineGray = color(hex: 0x8B95A4)
    let deleted = color(hex: 0xEF4444)
    let inserted = color(hex: 0x22C55E)
    let strike = color(hex: 0x1F2937)

    if let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [blue, indigo] as CFArray,
        locations: [0, 1]
    ) {
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: side / 2, y: side),
            end: CGPoint(x: side / 2, y: 0),
            options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
        )
    }

    let sheetWidth = (side * 0.60).rounded()
    let sheetHeight = (side * 0.68).rounded()
    let sheet = CGRect(
        x: ((side - sheetWidth) / 2).rounded(),
        y: ((side - sheetHeight) / 2).rounded(),
        width: sheetWidth,
        height: sheetHeight
    )
    let sheetRadius: CGFloat = 56
    let sheetPath = CGPath(
        roundedRect: sheet,
        cornerWidth: sheetRadius,
        cornerHeight: sheetRadius,
        transform: nil
    )

    context.saveGState()
    context.setShadow(
        offset: CGSize(width: 0, height: -16),
        blur: 36,
        color: color(hex: 0x1E1B4B, alpha: 0.22)
    )
    context.addPath(sheetPath)
    context.setFillColor(paper)
    context.fillPath()
    context.restoreGState()

    let padX: CGFloat = 68
    let barHeight: CGFloat = 64
    let barGap: CGFloat = 48
    let wordGap: CGFloat = 20
    let blockHeight = barHeight * 4 + barGap * 3
    let content = CGRect(
        x: sheet.minX + padX,
        y: sheet.midY - blockHeight / 2,
        width: sheet.width - padX * 2,
        height: blockHeight
    )

    let lines: [[Segment]] = [
        [Segment(fraction: 0.92, fill: lineGray)],
        [
            Segment(fraction: 0.42, fill: lineGray),
            Segment(fraction: 0.30, fill: deleted, struck: true),
        ],
        [
            Segment(fraction: 0.30, fill: lineGray),
            Segment(fraction: 0.44, fill: inserted),
        ],
        [Segment(fraction: 0.56, fill: lineGray)],
    ]

    for (index, line) in lines.enumerated() {
        let y = content.maxY - barHeight - CGFloat(index) * (barHeight + barGap)
        var x = content.minX
        for segment in line {
            let width = (content.width * segment.fraction).rounded()
            let rect = CGRect(x: x.rounded(), y: y.rounded(), width: width, height: barHeight)
            fillCapsule(rect, fill: segment.fill, in: context)
            if segment.struck {
                let thickness: CGFloat = 12
                let inset: CGFloat = 18
                let strikeRect = CGRect(
                    x: rect.minX + inset,
                    y: rect.midY - thickness / 2,
                    width: rect.width - inset * 2,
                    height: thickness
                )
                fillCapsule(strikeRect, fill: strike, in: context)
            }
            x += width + wordGap
        }
    }
}

func opaquePNG(from pixels: [UInt8], width: Int, height: Int) -> CGImage? {
    var rgb = [UInt8](repeating: 0, count: width * height * 3)
    rgb.withUnsafeMutableBytes { raw in
        guard let destination = raw.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
            return
        }
        for pixel in 0..<(width * height) {
            let source = pixel * 4
            let target = pixel * 3
            let alpha = Int(pixels[source + 3])
            if alpha == 255 {
                destination[target] = pixels[source]
                destination[target + 1] = pixels[source + 1]
                destination[target + 2] = pixels[source + 2]
            } else if alpha == 0 {
                destination[target] = 255
                destination[target + 1] = 255
                destination[target + 2] = 255
            } else {
                let inverse = 255 - alpha
                destination[target] = UInt8(min(255, Int(pixels[source]) + inverse))
                destination[target + 1] = UInt8(min(255, Int(pixels[source + 1]) + inverse))
                destination[target + 2] = UInt8(min(255, Int(pixels[source + 2]) + inverse))
            }
        }
    }

    let data = Data(rgb) as CFData
    guard let provider = CGDataProvider(data: data) else {
        return nil
    }
    return CGImage(
        width: width,
        height: height,
        bitsPerComponent: 8,
        bitsPerPixel: 24,
        bytesPerRow: width * 3,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
        provider: provider,
        decode: nil,
        shouldInterpolate: false,
        intent: .defaultIntent
    )
}

let bytesPerRow = canvas * 4
var pixels = [UInt8](repeating: 0, count: canvas * bytesPerRow)
let drew = pixels.withUnsafeMutableBytes { raw -> Bool in
    guard let context = CGContext(
        data: raw.baseAddress,
        width: canvas,
        height: canvas,
        bitsPerComponent: 8,
        bytesPerRow: bytesPerRow,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        return false
    }
    context.setAllowsAntialiasing(true)
    context.setShouldAntialias(true)
    context.interpolationQuality = .high
    context.setFillColor(color(hex: 0x3B82F6))
    context.fill(CGRect(x: 0, y: 0, width: canvas, height: canvas))
    drawIcon(in: context)
    return true
}

guard drew, let image = opaquePNG(from: pixels, width: canvas, height: canvas) else {
    fputs("Не удалось нарисовать иконку\n", stderr)
    exit(1)
}

let output = projectRoot()
    .appendingPathComponent("test/Assets.xcassets/AppIcon.appiconset/icon-1024.png")
try? FileManager.default.createDirectory(
    at: output.deletingLastPathComponent(),
    withIntermediateDirectories: true
)

guard let destination = CGImageDestinationCreateWithURL(
    output as CFURL,
    UTType.png.identifier as CFString,
    1,
    nil
) else {
    fputs("Не удалось создать PNG\n", stderr)
    exit(1)
}
CGImageDestinationAddImage(destination, image, nil)
guard CGImageDestinationFinalize(destination) else {
    fputs("Не удалось записать PNG\n", stderr)
    exit(1)
}
