import AppKit

// 原创 App 图标：沿用菜单栏的电池笑脸，以薄荷绿底色区分于系统电池图标。
// 使用矢量路径逐尺寸绘制，再由 iconutil 打包，包含 Retina 图标。
let root = URL(fileURLWithPath: CommandLine.arguments[1])
let iconset = root.appendingPathComponent(".build/AppIcon.iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

func render(size: Int) throws -> Data {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    defer { NSGraphicsContext.restoreGraphicsState() }
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    let transform = NSAffineTransform()
    transform.scale(by: CGFloat(size) / 1024)
    transform.concat()
    NSGraphicsContext.current?.shouldAntialias = true
    let tile = NSBezierPath(roundedRect: NSRect(x: 62, y: 62, width: 900, height: 900), xRadius: 206, yRadius: 206)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.22)
    shadow.shadowOffset = NSSize(width: 0, height: -12)
    shadow.shadowBlurRadius = 22
    shadow.set()
    NSColor(calibratedRed: 0.20, green: 0.70, blue: 0.52, alpha: 1).setFill()
    tile.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGradient(starting: NSColor(calibratedRed: 0.24, green: 0.72, blue: 0.56, alpha: 1),
               ending: NSColor(calibratedRed: 0.68, green: 0.96, blue: 0.78, alpha: 1))!.draw(in: tile, angle: 80)
    NSColor.white.withAlphaComponent(0.3).setStroke()
    tile.lineWidth = 3
    tile.stroke()

    let ink = NSColor(calibratedRed: 0.06, green: 0.23, blue: 0.20, alpha: 1)
    let body = NSBezierPath(roundedRect: NSRect(x: 196, y: 340, width: 585, height: 354), xRadius: 96, yRadius: 96)
    NSGraphicsContext.saveGraphicsState()
    let bodyShadow = NSShadow()
    bodyShadow.shadowColor = ink.withAlphaComponent(0.16)
    bodyShadow.shadowOffset = NSSize(width: 0, height: -14)
    bodyShadow.shadowBlurRadius = 18
    bodyShadow.set()
    NSColor(calibratedWhite: 0.99, alpha: 1).setFill()
    body.fill()
    NSGraphicsContext.restoreGraphicsState()
    ink.setStroke()
    body.lineWidth = 19
    body.stroke()
    ink.setFill()
    NSBezierPath(roundedRect: NSRect(x: 803, y: 447, width: 37, height: 140), xRadius: 18, yRadius: 18).fill()
    for x: CGFloat in [352, 621] {
        NSBezierPath(ovalIn: NSRect(x: x - 17, y: 524, width: 34, height: 57)).fill()
    }
    let smile = NSBezierPath()
    smile.lineWidth = 20
    smile.lineCapStyle = .round
    smile.move(to: NSPoint(x: 429, y: 492))
    smile.curve(to: NSPoint(x: 545, y: 492), controlPoint1: NSPoint(x: 451, y: 426), controlPoint2: NSPoint(x: 523, y: 426))
    smile.stroke()
    NSColor(calibratedRed: 0.97, green: 0.63, blue: 0.55, alpha: 0.6).setFill()
    for x: CGFloat in [303, 648] {
        NSBezierPath(ovalIn: NSRect(x: x, y: 462, width: 44, height: 19)).fill()
    }
    ink.withAlphaComponent(0.18).setFill()
    NSBezierPath(roundedRect: NSRect(x: 310, y: 278, width: 370, height: 17), xRadius: 8.5, yRadius: 8.5).fill()
    ink.setFill()
    NSBezierPath(roundedRect: NSRect(x: 310, y: 278, width: 278, height: 17), xRadius: 8.5, yRadius: 8.5).fill()
    return bitmap.representation(using: .png, properties: [:])!
}
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let data = try render(size: points * scale)
        let suffix = scale == 2 ? "@2x" : ""
        try data.write(to: iconset.appendingPathComponent("icon_\(points)x\(points)\(suffix).png"))
        if points == 512 && scale == 2 {
            try data.write(to: root.appendingPathComponent("Resources/AppIcon.png"))
        }
    }
}
print("Generated 10 icon sizes in \(iconset.path)")
