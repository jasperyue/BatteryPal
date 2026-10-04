import AppKit

/// 各主题接收相同状态及动画参数。禁止在渲染器内添加计时器、读取电源或写入偏好。
protocol IconThemeRenderer {
    static func image(_ state: BatteryState, ink: NSColor, boltOpacity: CGFloat, blink: Bool) -> NSImage
}

/// 稳定 ID 用于 UserDefaults，不能使用菜单序号作为持久化标识。
/// 新主题只需实现渲染器并在 allCases 中注册；菜单和预览会自动列出。
struct IconTheme: Hashable {
    let rawValue: String
    let labelKey: String
    let previewTitle: String
    private let renderer: IconThemeRenderer.Type
    private let svgAssets: SVGThemeAssets?
    private let importedName: String?

    init(id: String, labelKey: String, previewTitle: String, renderer: IconThemeRenderer.Type) {
        self.rawValue = id
        self.labelKey = labelKey
        self.previewTitle = previewTitle
        self.renderer = renderer
        self.svgAssets = nil
        self.importedName = nil
    }
    init(id: String, name: String, assets: SVGThemeAssets) {
        rawValue = id
        labelKey = ""
        previewTitle = name
        renderer = BatteryTheme.self
        svgAssets = assets
        importedName = name
    }
    var displayName: String { importedName ?? L10n.text(labelKey) }
    var isImported: Bool { svgAssets != nil }
    init?(rawValue: String) {
        guard let theme = Self.allCases.first(where: { $0.rawValue == rawValue }) else { return nil }
        self = theme
    }
    static let battery = IconTheme(id: "battery", labelKey: "theme_battery", previewTitle: "BATTERY", renderer: BatteryTheme.self)
    static let pineapple = IconTheme(id: "pineapple", labelKey: "theme_pineapple", previewTitle: "PINEAPPLE", renderer: PineappleTheme.self)
    static var allCases: [IconTheme] { [.battery, .pineapple] + ThemeLibrary.shared.themes }

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.rawValue == rhs.rawValue }
    func hash(into hasher: inout Hasher) { hasher.combine(rawValue) }
    func image(_ state: BatteryState, ink: NSColor, boltOpacity: CGFloat, blink: Bool) -> NSImage {
        if let assets = svgAssets, let layer = assets.image(named: PineappleTheme.resourceName(state, boltOpacity: boltOpacity, blink: blink)) {
            return PineappleTheme.compose(layer, state: state, ink: ink)
        }
        return renderer.image(state, ink: ink, boltOpacity: boltOpacity, blink: blink)
    }
}

// 绘图入口：调用者无需 switch 主题。新增主题不会影响动画缓存或菜单栏刷新逻辑。
enum BatteryArt {
    static func image(_ state: BatteryState, ink: NSColor = .black, boltOpacity: CGFloat = 1,
                      blink: Bool = false, theme: IconTheme = .battery) -> NSImage {
        theme.image(state, ink: ink, boltOpacity: boltOpacity, blink: blink)
    }
}
