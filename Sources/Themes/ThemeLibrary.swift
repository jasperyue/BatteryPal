import AppKit

struct ThemeImportError: LocalizedError {
    let key: String
    let detail: String
    init(_ key: String, _ detail: String = "") { self.key = key; self.detail = detail }
    var errorDescription: String? {
        L10n.text(key) + (detail.isEmpty ? "" : "\n" + detail)
    }
}

/// 导入仅接受静态矢量图形；不加载脚本、外链、字体或嵌入图片。
final class ThemeSVGValidator: NSObject, XMLParserDelegate {
    static let maxFileBytes = 128 * 1024
    static let maxGroupBytes = 512 * 1024
    private let allowed: Set<String> = ["svg", "g", "path", "circle", "ellipse", "rect",
                                       "line", "polyline", "polygon", "defs", "clipPath", "title", "desc"]
    private var rootFound = false
    private var depth = 0
    private var valid = true
    private var filename = ""

    static func validate(_ data: Data, filename: String, render: Bool = true) throws {
        guard !data.isEmpty, data.count <= maxFileBytes else { throw ThemeImportError("theme_file_size", filename) }
        guard let source = String(data: data, encoding: .utf8),
              !source.uppercased().contains("<!DOCTYPE"), !source.uppercased().contains("<!ENTITY") else {
            throw ThemeImportError("theme_svg_static", filename)
        }
        let delegate = ThemeSVGValidator()
        delegate.filename = filename
        let parser = XMLParser(data: data)
        parser.shouldResolveExternalEntities = false
        parser.delegate = delegate
        guard parser.parse(), delegate.valid, delegate.rootFound else {
            throw ThemeImportError("theme_svg_format", filename)
        }
        let normalized = source.replacingOccurrences(of: "currentColor", with: "#000000")
        guard let image = NSImage(data: Data(normalized.utf8)), image.isValid,
              image.size == NSSize(width: 28, height: 18) else {
            throw ThemeImportError("theme_svg_decode", filename)
        }
        if render {
            let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 56, pixelsHigh: 36,
                bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
            image.draw(in: NSRect(x: 0, y: 0, width: 56, height: 36))
            NSGraphicsContext.restoreGraphicsState()
            var visible = false
            for x in 0..<56 {
                for y in 0..<36 where (bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.01 { visible = true }
            }
            guard visible else { throw ThemeImportError("theme_svg_empty", filename) }
        }
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?, attributes attributesDict: [String: String]) {
        guard allowed.contains(elementName), (depth == 0 ? elementName == "svg" : elementName != "svg") else {
            valid = false; parser.abortParsing(); return
        }
        if depth == 0 {
            rootFound = true
            let viewBox = attributesDict["viewBox"]?.split(whereSeparator: { $0.isWhitespace || $0 == "," }).compactMap { Double($0) }
            func dimension(_ name: String) -> Double? {
                attributesDict[name].flatMap { Double($0.replacingOccurrences(of: "px", with: "")) }
            }
            guard viewBox == [0, 0, 28, 18], dimension("width") == 28, dimension("height") == 18 else {
                valid = false; parser.abortParsing(); return
            }
        }
        for (key, value) in attributesDict {
            let lower = key.lowercased()
            let text = value.lowercased()
            if lower.hasPrefix("on") || lower == "style" || lower == "href" || lower == "xlink:href"
                || (text.contains("url(") && text.range(of: #"^url\(\s*#[a-z0-9_.:-]+\s*\)$"#, options: .regularExpression) == nil) {
                valid = false; parser.abortParsing(); return
            }
        }
        depth += 1
    }
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        depth -= 1
    }
}

/// 用户库与应用资源分离，UUID 作为稳定主题 ID；新导入不会覆盖已存在主题。
final class ThemeLibrary {
    static let localizationKeys = ["theme_library","theme_open_folder","theme_import","theme_export_template","theme_refresh","theme_library_hint","theme_active","theme_use","theme_imported","theme_builtin","theme_low","theme_normal","theme_high","theme_unknown","theme_bright","theme_dim","theme_blink","theme_import_hint","theme_name_prompt","theme_cancel","theme_export_hint","theme_error_title","theme_file_count","theme_file_size","theme_group_size","theme_svg_static","theme_svg_format","theme_svg_decode","theme_svg_empty","theme_name_invalid","theme_folder_error","theme_export_exists"]
    static let shared = ThemeLibrary()
    static let filenames = PineappleTheme.resourceNames.map { $0 + ".svg" }
    struct Manifest: Codable { let id: String; let name: String }
    let directory: URL
    private(set) var themes: [IconTheme] = []
    private let manager = FileManager.default

    init(directory: URL? = nil) {
        self.directory = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Battery Pie/Themes", isDirectory: true)
        reload()
    }
    @discardableResult func ensureDirectory() throws -> URL {
        try manager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
    func reload() {
        themes = []
        let folders = (try? manager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
            options: .skipsHiddenFiles)) ?? []
        for folder in folders.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            guard folder.lastPathComponent.hasPrefix("custom-"),
                  let values = try? folder.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]),
                  values.isDirectory == true, values.isSymbolicLink != true,
                  let data = try? Data(contentsOf: folder.appendingPathComponent("theme.json")), data.count <= 4096,
                  let manifest = try? JSONDecoder().decode(Manifest.self, from: data),
                  manifest.id == folder.lastPathComponent, !manifest.name.isEmpty, manifest.name.count <= 64,
                  (try? Self.validatedFiles(in: folder, allowManifest: true, render: false)) != nil else { continue }
            themes.append(IconTheme(id: manifest.id, name: manifest.name, assets: SVGThemeAssets(directory: folder)))
        }
        themes.sort { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
    }
    static func validatedFiles(in folder: URL, allowManifest: Bool = false, render: Bool = true) throws -> [String: Data] {
        let urls = try FileManager.default.contentsOfDirectory(at: folder,
            includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey], options: .skipsHiddenFiles)
        let assets = urls.filter { !(allowManifest && $0.lastPathComponent == "theme.json") }
        guard assets.count == filenames.count, Set(assets.map(\.lastPathComponent)) == Set(filenames) else {
            throw ThemeImportError("theme_file_count", filenames.joined(separator: ", "))
        }
        var result: [String: Data] = [:]
        var total = 0
        for url in assets {
            let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
            guard values.isRegularFile == true, values.isSymbolicLink != true else {
                throw ThemeImportError("theme_svg_format", url.lastPathComponent)
            }
            guard let size = values.fileSize, size <= ThemeSVGValidator.maxFileBytes else {
                throw ThemeImportError("theme_file_size", url.lastPathComponent)
            }
            let data = try Data(contentsOf: url, options: .mappedIfSafe)
            total += data.count
            guard total <= ThemeSVGValidator.maxGroupBytes else { throw ThemeImportError("theme_group_size") }
            try ThemeSVGValidator.validate(data, filename: url.lastPathComponent, render: render)
            result[url.lastPathComponent] = data
        }
        return result
    }
    @discardableResult func importTheme(from folder: URL, name: String) throws -> IconTheme {
        let title = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, title.count <= 64 else { throw ThemeImportError("theme_name_invalid") }
        let files = try Self.validatedFiles(in: folder)
        try ensureDirectory()
        let id = "custom-" + UUID().uuidString.lowercased()
        let stage = directory.appendingPathComponent("." + id)
        let destination = directory.appendingPathComponent(id)
        try manager.createDirectory(at: stage, withIntermediateDirectories: false)
        defer { try? manager.removeItem(at: stage) }
        for (name, data) in files { try data.write(to: stage.appendingPathComponent(name), options: .atomic) }
        try JSONEncoder().encode(Manifest(id: id, name: title)).write(to: stage.appendingPathComponent("theme.json"), options: .atomic)
        try manager.moveItem(at: stage, to: destination)
        reload()
        guard let theme = themes.first(where: { $0.rawValue == id }) else { throw ThemeImportError("theme_svg_decode") }
        return theme
    }
}
