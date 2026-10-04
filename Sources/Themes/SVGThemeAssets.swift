import AppKit

/// 仅在首次加载主题时读文件；动画计时器复用缓存，不逐帧解析 SVG。
/// 外部文件缺失或无法解码时逐项回退到应用内资源。
final class SVGThemeAssets {
    let directory: URL
    let overrideDirectory: URL?
    private var images: [String: NSImage] = [:]
    private var attempted: Set<String> = []

    init(directory: URL, overrideDirectory: URL? = nil) {
        self.directory = directory
        self.overrideDirectory = overrideDirectory
    }

    func image(named name: String) -> NSImage? {
        if attempted.contains(name) { return images[name] }
        attempted.insert(name)
        let candidates = [overrideDirectory, directory].compactMap { $0 }
        for directory in candidates {
            let url = directory.appendingPathComponent(name).appendingPathExtension("svg")
            guard let image = Self.load(url) else { continue }
            images[name] = image
            return image
        }
        return nil
    }

    private static func load(_ url: URL) -> NSImage? {
        guard let source = try? String(contentsOf: url, encoding: .utf8),
              source.contains("<svg"),
              let data = source.replacingOccurrences(of: "currentColor", with: "#000000").data(using: .utf8),
              let image = NSImage(data: data), image.isValid else { return nil }
        image.isTemplate = false
        return image
    }
}
