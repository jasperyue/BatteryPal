import AppKit

// OpenDesign A 版由 SVG 文件决定轮廓与表情。Swift 只组合模板色和实际电量轨道。
enum PineappleTheme: IconThemeRenderer {
    static let resourceNames = ["low", "normal", "high", "unknown",
                                "charging-frame-1", "charging-frame-2", "charging-frame-3"]
    static let assets: SVGThemeAssets = {
        let bundled = (Bundle.main.resourceURL ?? Bundle.main.bundleURL)
            .appendingPathComponent("Themes/pineapple", isDirectory: true)
        let custom = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?.appendingPathComponent("Battery Pie/Themes/pineapple", isDirectory: true)
        return SVGThemeAssets(directory: bundled, overrideDirectory: custom)
    }()

    static func image(_ state: BatteryState, ink: NSColor = .black,
                      boltOpacity: CGFloat = 1, blink: Bool = false) -> NSImage {
        let name = state.mood == "charging"
            ? "charging-frame-\(blink ? 3 : (boltOpacity < 0.7 ? 2 : 1))" : state.mood
        guard let layer = assets.image(named: name) else {
            // 不依赖私有 SVG API；解码不可用的系统继续使用已验证的原生路径。
            return PineappleFallbackArt.image(state, ink: ink, boltOpacity: boltOpacity, blink: blink)
        }
        let image = NSImage(size: NSSize(width: 28, height: 18), flipped: false) { _ in
            NSGraphicsContext.saveGraphicsState()
            defer { NSGraphicsContext.restoreGraphicsState() }
            layer.draw(in: NSRect(x: 0, y: 0, width: 28, height: 18),
                       from: .zero, operation: .sourceOver, fraction: 1)
            // SVG 的 alpha 作为模板遮罩，保留暗闪电的透明度。
            ink.setFill()
            NSRect(x: 0, y: 0, width: 28, height: 18).fill(using: .sourceIn)
            func line(to end: CGFloat) {
                let path = NSBezierPath()
                path.lineWidth = 1
                path.lineCapStyle = .round
                path.move(to: NSPoint(x: 6, y: 1.5))
                path.line(to: NSPoint(x: end, y: 1.5))
                path.stroke()
            }
            ink.withAlphaComponent(ink.alphaComponent * 0.22).setStroke()
            line(to: 22)
            if let percent = state.percent, percent > 0 {
                ink.setStroke()
                line(to: 6 + 16 * CGFloat(min(100, percent)) / 100)
            }
            return true
        }
        image.isTemplate = true
        return image
    }
}
