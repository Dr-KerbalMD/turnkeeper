// Draws the app icon and writes Resources/AppIcon.icns for the Mac and the full-bleed
// ios/App/Assets.xcassets/AppIcon.appiconset/icon-1024.png for the iPad.
// Usage: swift scripts/make-icon.swift
//
// The artwork is original: initiative magnets on a combat pad, a turn arrow and a twenty-sided die.
// It uses no Paizo logos, lettering or artwork.
import AppKit

let canvas: CGFloat = 1024

func color(_ hex: UInt32, alpha: CGFloat = 1) -> CGColor {
    CGColor(
        red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255, alpha: alpha
    )
}

func fillGradient(_ context: CGContext, in path: CGPath, from top: UInt32, to bottom: UInt32) {
    context.saveGState()
    context.addPath(path)
    context.clip()
    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                              colors: [color(top), color(bottom)] as CFArray, locations: [0, 1])
    let bounds = path.boundingBox
    if let gradient {
        context.drawLinearGradient(gradient, start: CGPoint(x: bounds.midX, y: bounds.maxY),
                                   end: CGPoint(x: bounds.midX, y: bounds.minY), options: [])
    }
    context.restoreGState()
}

/// A heavy system font at a size and color.
struct Lettering {
    var size: CGFloat
    var hex: UInt32
}

func drawText(_ context: CGContext, _ text: String, center: CGPoint, style: Lettering) {
    let font = NSFont.systemFont(ofSize: style.size, weight: .heavy)
    let ink = NSColor(cgColor: color(style.hex)) ?? .white
    let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: ink]
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes))
    let bounds = CTLineGetBoundsWithOptions(line, .useOpticalBounds)
    context.textPosition = CGPoint(x: center.x - bounds.midX, y: center.y - bounds.midY)
    CTLineDraw(line, context)
}

/// The pad: a dark slate board with a faint grid, like the dry-erase surface of the paper combat pad.
func drawPad(_ context: CGContext, in rect: CGRect, corner: CGFloat) {
    let pad = CGPath(roundedRect: rect, cornerWidth: corner, cornerHeight: corner, transform: nil)
    fillGradient(context, in: pad, from: 0x2A3442, to: 0x0E131B)
    context.saveGState()
    context.addPath(pad)
    context.clip()
    context.setStrokeColor(color(0xFFFFFF, alpha: 0.05))
    context.setLineWidth(3)
    stride(from: rect.minX, through: rect.maxX, by: 64).forEach { column in
        context.move(to: CGPoint(x: column, y: rect.minY))
        context.addLine(to: CGPoint(x: column, y: rect.maxY))
    }
    stride(from: rect.minY, through: rect.maxY, by: 64).forEach { row in
        context.move(to: CGPoint(x: rect.minX, y: row))
        context.addLine(to: CGPoint(x: rect.maxX, y: row))
    }
    context.strokePath()
    context.restoreGState()
}

/// A magnet strip: a glossy colored bar with an initiative badge and a round token.
func drawMagnet(_ context: CGContext, frame: CGRect, colors: (UInt32, UInt32), initiative: String) {
    let strip = CGPath(roundedRect: frame, cornerWidth: 34, cornerHeight: 34, transform: nil)
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -12), blur: 24, color: color(0x000000, alpha: 0.55))
    context.addPath(strip)
    context.setFillColor(color(colors.1))
    context.fillPath()
    context.restoreGState()
    fillGradient(context, in: strip, from: colors.0, to: colors.1)
    let shine = CGRect(x: frame.minX + 12, y: frame.midY + 4, width: frame.width - 24, height: frame.height / 2 - 14)
    fillGradientAlpha(context, in: CGPath(roundedRect: shine, cornerWidth: 24, cornerHeight: 24, transform: nil))

    let badge = CGRect(x: frame.minX + 28, y: frame.midY - 52, width: 120, height: 104)
    context.addPath(CGPath(roundedRect: badge, cornerWidth: 20, cornerHeight: 20, transform: nil))
    context.setFillColor(color(0x000000, alpha: 0.35))
    context.fillPath()
    drawText(context, initiative, center: CGPoint(x: badge.midX, y: badge.midY),
             style: Lettering(size: 72, hex: 0xFFFFFF))

    let token = CGRect(x: badge.maxX + 26, y: frame.midY - 54, width: 108, height: 108)
    context.addEllipse(in: token)
    context.setFillColor(color(0xFFFFFF, alpha: 0.9))
    context.fillPath()
    context.addEllipse(in: token.insetBy(dx: 12, dy: 12))
    context.setFillColor(color(colors.1, alpha: 0.85))
    context.fillPath()
    let bar = CGRect(x: token.maxX + 32, y: frame.midY - 14, width: frame.maxX - token.maxX - 80, height: 28)
    context.addPath(CGPath(roundedRect: bar, cornerWidth: 14, cornerHeight: 14, transform: nil))
    context.setFillColor(color(0xFFFFFF, alpha: 0.35))
    context.fillPath()
}

func fillGradientAlpha(_ context: CGContext, in path: CGPath) {
    context.saveGState()
    context.addPath(path)
    context.clip()
    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                              colors: [color(0xFFFFFF, alpha: 0.35), color(0xFFFFFF, alpha: 0)] as CFArray,
                              locations: [0, 1])
    let bounds = path.boundingBox
    if let gradient {
        context.drawLinearGradient(gradient, start: CGPoint(x: bounds.midX, y: bounds.maxY),
                                   end: CGPoint(x: bounds.midX, y: bounds.minY), options: [])
    }
    context.restoreGState()
}

/// The gold turn arrow pointing at the strip whose turn it is.
func drawArrow(_ context: CGContext, tip: CGPoint) {
    let arrow = CGMutablePath()
    arrow.move(to: tip)
    arrow.addLine(to: CGPoint(x: tip.x - 92, y: tip.y + 62))
    arrow.addLine(to: CGPoint(x: tip.x - 92, y: tip.y - 62))
    arrow.closeSubpath()
    context.saveGState()
    context.setShadow(offset: .zero, blur: 30, color: color(0xFFC94A, alpha: 0.9))
    context.addPath(arrow)
    context.setFillColor(color(0xFFD45C))
    context.fillPath()
    context.restoreGState()
    fillGradient(context, in: arrow, from: 0xFFE89A, to: 0xE09A1C)
}

/// The geometry of a twenty-sided die seen face on: a hexagon outline around an upward front face.
struct DieShape {
    var center: CGPoint
    var radius: CGFloat
    let hexagonAngles: [CGFloat] = [90, 150, 210, 270, 330, 30]
    let faceAngles: [CGFloat] = [90, 210, 330]

    func point(_ degrees: CGFloat, _ scale: CGFloat) -> CGPoint {
        let angle = degrees * .pi / 180
        return CGPoint(x: center.x + radius * scale * cos(angle), y: center.y + radius * scale * sin(angle))
    }

    func path(_ points: [CGPoint]) -> CGPath {
        let path = CGMutablePath()
        path.addLines(between: points)
        path.closeSubpath()
        return path
    }

    var outline: CGPath { path(hexagonAngles.map { point($0, 1) }) }
    var front: CGPath { path(faceAngles.map { point($0, 0.55) }) }

    /// Each outer edge meets the nearest corner of the front face; each front edge meets the hexagon corner
    /// between its ends. Together the triangles tile the hexagon.
    var facets: [[CGPoint]] {
        var facets: [[CGPoint]] = []
        for (index, start) in hexagonAngles.enumerated() {
            let middle = start + 30
            let nearest = faceAngles.min { distance($0, middle) < distance($1, middle) } ?? 90
            facets.append([point(start, 1), point(hexagonAngles[(index + 1) % 6], 1), point(nearest, 0.55)])
        }
        for (first, second, corner) in [(90.0, 210.0, 150.0), (210.0, 330.0, 270.0), (330.0, 90.0, 30.0)] {
            facets.append([point(first, 0.55), point(second, 0.55), point(corner, 1)])
        }
        return facets
    }
}

/// A gold twenty-sided die showing 20, with shaded facets and a warm glow.
func drawDie(_ context: CGContext, center: CGPoint, radius: CGFloat) {
    let die = DieShape(center: center, radius: radius)
    context.saveGState()
    context.setShadow(offset: .zero, blur: 60, color: color(0xFFB627, alpha: 0.75))
    context.addPath(die.outline)
    context.setFillColor(color(0xC98A12))
    context.fillPath()
    context.restoreGState()
    let shades: [UInt32] = [0xF7C948, 0xE3A520, 0xB8790C, 0xA86B08, 0xD99A1A, 0xF0BA35, 0xE8AE2C, 0xC88A14, 0xF3C043]
    for (facet, shade) in zip(die.facets, shades) {
        context.addPath(die.path(facet))
        context.setFillColor(color(shade))
        context.fillPath()
    }
    fillGradient(context, in: die.front, from: 0xFFEBA6, to: 0xF2B632)
    context.setStrokeColor(color(0x7A4A05, alpha: 0.75))
    context.setLineWidth(6)
    context.setLineJoin(.round)
    die.facets.forEach { context.addPath(die.path($0)) }
    context.addPath(die.outline)
    context.strokePath()
    drawText(context, "20", center: CGPoint(x: center.x, y: center.y - radius * 0.1),
             style: Lettering(size: radius * 0.36, hex: 0x5A3300))
}

/// The smaller angle between two directions, in degrees.
func distance(_ first: CGFloat, _ second: CGFloat) -> CGFloat {
    let difference = abs(first - second).truncatingRemainder(dividingBy: 360)
    return min(difference, 360 - difference)
}

func drawIcon(_ context: CGContext, padRect: CGRect, corner: CGFloat) {
    drawPad(context, in: padRect, corner: corner)
    let scale = padRect.width / canvas
    context.saveGState()
    context.translateBy(x: padRect.minX, y: padRect.minY)
    context.scaleBy(x: scale, y: scale)
    let strips: [((UInt32, UInt32), String)] = [((0xE5483B, 0x9E1C14), "22"), ((0x3D86E0, 0x1A4C99), "17"),
                                                ((0x47A84E, 0x1F6B26), "12")]
    for (index, strip) in strips.enumerated() {
        let frame = CGRect(x: 170, y: 690 - CGFloat(index) * 200, width: 720, height: 160)
        drawMagnet(context, frame: frame, colors: strip.0, initiative: strip.1)
    }
    drawArrow(context, tip: CGPoint(x: 160, y: 770))
    drawDie(context, center: CGPoint(x: 790, y: 250), radius: 190)
    context.restoreGState()
}

func render(size: CGFloat, padRect: CGRect, corner: CGFloat) -> NSBitmapImageRep {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size), bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ), let context = NSGraphicsContext(bitmapImageRep: bitmap)?.cgContext else {
        fatalError("Drawing the icon failed: no bitmap context")
    }
    context.scaleBy(x: size / canvas, y: size / canvas)
    drawIcon(context, padRect: padRect, corner: corner)
    return bitmap
}

func write(_ bitmap: NSBitmapImageRep, to path: String) throws {
    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        throw CocoaError(.fileWriteUnknown)
    }
    try data.write(to: URL(fileURLWithPath: path))
}

let fileManager = FileManager.default
try fileManager.createDirectory(atPath: "Resources", withIntermediateDirectories: true)

// iPad: full bleed; the system applies the rounded mask.
try write(render(size: 1024, padRect: CGRect(x: 0, y: 0, width: canvas, height: canvas), corner: 0),
          to: "ios/App/Assets.xcassets/AppIcon.appiconset/icon-1024.png")

// Mac: the rounded square sits inside the standard 1024 grid with margins for the shadow.
let iconset = "tmp/AppIcon.iconset"
try? fileManager.removeItem(atPath: iconset)
try fileManager.createDirectory(atPath: iconset, withIntermediateDirectories: true)
let macPad = CGRect(x: 100, y: 100, width: 824, height: 824)
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = CGFloat(points * scale)
        let name = scale == 1 ? "icon_\(points)x\(points).png" : "icon_\(points)x\(points)@2x.png"
        try write(render(size: pixels, padRect: macPad, corner: 185), to: "\(iconset)/\(name)")
    }
}
let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset, "-o", "Resources/AppIcon.icns"]
try iconutil.run()
iconutil.waitUntilExit()
try? fileManager.removeItem(atPath: iconset)
print(iconutil.terminationStatus == 0 ? "Wrote Resources/AppIcon.icns and the iPad icon." : "iconutil failed.")
