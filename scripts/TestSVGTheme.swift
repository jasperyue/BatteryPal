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
        try testLibrary()
    }

    static func testLibrary() throws {
        let fm = FileManager.default
        let temp = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fm.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: temp) }
        let source = temp.appendingPathComponent("source")
        try fm.copyItem(at: PineappleTheme.assets.directory, to: source)
        let library = ThemeLibrary(directory: temp.appendingPathComponent("library"))
        precondition(!fm.fileExists(atPath: library.directory.path))
        try library.ensureDirectory()
        precondition(fm.fileExists(atPath: library.directory.path))
        let imported = try library.importTheme(from: source, name: "Test SVG Theme")
        precondition(imported.isImported && library.themes.count == 1)
        let reopened = ThemeLibrary(directory: library.directory)
        precondition(reopened.themes.first?.rawValue == imported.rawValue)
        precondition(reopened.themes.first?.displayName == "Test SVG Theme")
        let state = BatteryState(percent: 52, charging: true, pluggedIn: true, minutes: nil)
        precondition(bytes(imported.image(state, ink: .black, boltOpacity: 1, blink: false))
            != bytes(imported.image(state, ink: .black, boltOpacity: 0.35, blink: false)))
        func rejected(_ folder: URL) throws {
            let before = library.themes.count
            do {
                _ = try library.importTheme(from: folder, name: "Rejected")
                preconditionFailure("Invalid SVG group was imported")
            } catch is ThemeImportError {}
            precondition(library.themes.count == before, "Rejected import must not add a theme")
        }
        let low = source.appendingPathComponent("low.svg")
        let original = try Data(contentsOf: low)
        try fm.removeItem(at: low)
        try rejected(source)
        try original.write(to: low)
        let extra = source.appendingPathComponent("extra.svg")
        try original.write(to: extra)
        try rejected(source)
        try fm.removeItem(at: extra)
        try Data(repeating: 32, count: ThemeSVGValidator.maxFileBytes + 1).write(to: low)
        try rejected(source)
        for bad in [
            String(data: original, encoding: .utf8)!.replacingOccurrences(of: "width=\"28\"", with: "width=\"29\""),
            "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"28\" height=\"18\" viewBox=\"0 0 28 18\"/>",
            "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"28\" height=\"18\" viewBox=\"0 0 28 18\"><script>alert(1)</script></svg>",
            "<!DOCTYPE svg [<!ENTITY example SYSTEM \"file:///etc/passwd\">]><svg width=\"28\" height=\"18\" viewBox=\"0 0 28 18\"/>"
        ] {
            try Data(bad.utf8).write(to: low)
            try rejected(source)
        }
        try original.write(to: low)
        let link = source.appendingPathComponent("low.svg")
        try fm.removeItem(at: link)
        try fm.createSymbolicLink(at: link, withDestinationURL: PineappleTheme.assets.directory.appendingPathComponent("low.svg"))
        try rejected(source)
        try fm.removeItem(at: link)
        try original.write(to: link)
        for file in ThemeLibrary.filenames {
            let url = source.appendingPathComponent(file)
            var data = try Data(contentsOf: url)
            data.append(Data(("<!--" + String(repeating: " ", count: 90 * 1024) + "-->").utf8))
            try data.write(to: url)
        }
        try rejected(source)
        print("PASS: folder creation, atomic import, persistent IDs, preview frames and rejection of count/size/canvas/blank/script/entity/symlink violations")
    }
}
