import AppKit

@main
enum TestSVGTheme {
    static func bitmap(_ image: NSImage, scale: Int = 2) -> NSBitmapImageRep {
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 28 * scale,
            pixelsHigh: 18 * scale, bitsPerSample: 8, samplesPerPixel: 4,
            hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
            bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        let transform = NSAffineTransform()
        transform.scale(by: CGFloat(scale))
        transform.concat()
        image.isTemplate = false
        image.draw(in: NSRect(x: 0, y: 0, width: 28, height: 18))
        NSGraphicsContext.restoreGraphicsState()
        return bitmap
    }

    static func bytes(_ image: NSImage) -> Data {
        let rendered = bitmap(image)
        return Data(bytes: rendered.bitmapData!, count: rendered.bytesPerRow * rendered.pixelsHigh)
    }

    static func alpha(_ image: NSImage, x: Int, y: Int) -> CGFloat {
        bitmap(image).colorAt(x: x, y: y)!.alphaComponent
    }

    static func main() throws {
        let _ = NSApplication.shared
        // 此测试要求原生 SVG 实际加载成功，不能靠绘图回退通过。
        let bundled = SVGThemeAssets(directory: PineappleTheme.assets.directory)
        for name in PineappleTheme.resourceNames {
            let layer = bundled.image(named: name)!
            precondition(layer.size == NSSize(width: 28, height: 18))
            precondition(layer.representations.contains { String(describing: type(of: $0)).contains("SVG") })
            precondition(bundled.image(named: name) === layer, "SVG cache must reuse the same image")
        }
        print("PASS: all seven bundled SVGs decoded natively and cached")
        let state = BatteryState(percent: 52, charging: false, pluggedIn: false, minutes: nil)
        let normal = PineappleTheme.image(state)
        precondition(normal.isTemplate && normal.size == NSSize(width: 28, height: 18))
        let charging = BatteryState(percent: 52, charging: true, pluggedIn: true, minutes: nil)
        let bright = PineappleTheme.image(charging)
        let dim = PineappleTheme.image(charging, boltOpacity: 0.35)
        let blink = PineappleTheme.image(charging, blink: true)
        precondition(bytes(bright) != bytes(dim) && bytes(bright) != bytes(blink))
        // 右侧闪电内点：比较 alpha，避免只是看见不同的文件名。
        precondition(alpha(bright, x: 50, y: 18) > alpha(dim, x: 50, y: 18))
        print("PASS: charging opacity and blink produce distinct rendered frames")
        for ink in [NSColor.black, .white] {
            let rendered = bitmap(PineappleTheme.image(state, ink: ink))
            let expected = ink == .white ? CGFloat(1) : 0
            var painted = 0
            for x in 0..<rendered.pixelsWide {
                for y in 0..<rendered.pixelsHigh {
                    let color = rendered.colorAt(x: x, y: y)!
                    if color.alphaComponent > 0.5 {
                        precondition(abs(color.redComponent - expected) < 0.02)
                        painted += 1
                    }
                }
            }
            precondition(painted > 20)
        }
        print("PASS: black/white template tint retains nonempty artwork")
        let empty = BatteryState(percent: 0, charging: false, pluggedIn: false, minutes: nil)
        let full = BatteryState(percent: 100, charging: false, pluggedIn: false, minutes: nil)
        precondition(alpha(PineappleTheme.image(full), x: 40, y: 33) >
                     alpha(PineappleTheme.image(empty), x: 40, y: 33))
        precondition(alpha(PineappleTheme.image(.unavailable), x: 40, y: 33) < 0.3)
        print("PASS: dynamic battery track and unknown empty track")
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }
        let custom = temp.appendingPathComponent("normal.svg")
        try "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"28\" height=\"18\"><path d=\"M1 1H27V17H1Z\" fill=\"black\"/></svg>".write(to: custom, atomically: true, encoding: .utf8)
        let overridden = SVGThemeAssets(directory: bundled.directory, overrideDirectory: temp)
        precondition(bytes(overridden.image(named: "normal")!) != bytes(bundled.image(named: "normal")!))
        try "invalid SVG".write(to: custom, atomically: true, encoding: .utf8)
        let invalid = SVGThemeAssets(directory: bundled.directory, overrideDirectory: temp)
        precondition(bytes(invalid.image(named: "normal")!) == bytes(bundled.image(named: "normal")!))
        let missing = SVGThemeAssets(directory: temp)
        precondition(missing.image(named: "not-found") == nil)
        print("PASS: external SVG override, invalid override fallback, missing file handling")
        let fallback = PineappleFallbackArt.image(charging, blink: true)
        precondition(fallback.isTemplate && bytes(fallback).contains { $0 != 0 })
        print("PASS: native drawing compatibility fallback")
    }
}
