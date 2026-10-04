import AppKit

// 应用入口与诊断命令；业务逻辑在 AppDelegate、BatteryState 和 Themes 中。
if let previewIndex = CommandLine.arguments.firstIndex(of: "--render-preview"), CommandLine.arguments.count > previewIndex + 1 {
    // [AppKit] 初始化应用对象，使命令行预览路径也能使用 UI 绘图环境。
    let _ = NSApplication.shared
    let states: [BatteryState] = [
        BatteryState(percent: 12, charging: false, pluggedIn: false, minutes: nil),
        BatteryState(percent: 52, charging: false, pluggedIn: false, minutes: nil),
        BatteryState(percent: 92, charging: false, pluggedIn: false, minutes: nil),
        BatteryState(percent: 47, charging: true, pluggedIn: true, minutes: nil), .unavailable]
    let titles = ["LOW", "NORMAL", "HIGH", "CHARGING", "NO BATTERY"]
    let details = ["0–20%", "21–79%", "80–100%", "Overrides level", "Unavailable"]
    // [AppKit] 两个主题分别在明暗背景绘制；每列同时展示放大图与实际 28×18 点尺寸。
    let themes = IconTheme.allCases
    let preview = NSImage(size: NSSize(width: 1000, height: CGFloat(themes.count * 500)), flipped: false) { _ in
        for (themeIndex, theme) in themes.enumerated() {
            for dark in [false, true] {
                let base: CGFloat = CGFloat(themeIndex * 2 + (dark ? 0 : 1)) * 250
                let ink: NSColor = dark ? .white : NSColor(white: 0.12, alpha: 1)
                (dark ? NSColor(white: 0.10, alpha: 1) : NSColor(white: 0.97, alpha: 1)).setFill()
                NSRect(x: 0, y: base, width: 1000, height: 250).fill()
                for (index, state) in states.enumerated() {
                    let x = CGFloat(index * 200)
                    let icon = BatteryArt.image(state, ink: ink, theme: theme)
                    icon.isTemplate = false
                    icon.draw(in: NSRect(x: x + 58, y: base + 119, width: 84, height: 54))
                    icon.draw(in: NSRect(x: x + 86, y: base + 80, width: 28, height: 18))
                    let title = titles[index] as NSString
                    let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 12, weight: .semibold), .foregroundColor: ink]
                    title.draw(at: NSPoint(x: x + (200 - title.size(withAttributes: attrs).width) / 2, y: base + 48), withAttributes: attrs)
                    let detail = details[index] as NSString
                    let small: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: ink.withAlphaComponent(0.55)]
                    detail.draw(at: NSPoint(x: x + (200 - detail.size(withAttributes: small).width) / 2, y: base + 28), withAttributes: small)
                }
                let label = theme.previewTitle as NSString
                let labelAttrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 11, weight: .bold), .foregroundColor: ink.withAlphaComponent(0.5)]
                label.draw(at: NSPoint(x: 14, y: base + 12), withAttributes: labelAttrs)
            }
        }
        return true
    }
    // [AppKit] NSBitmapImageRep 将图像编码为 PNG；[Foundation] Data.write 和 URL 将其写入文件。
    if let tiff = preview.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff), let png = bitmap.representation(using: .png, properties: [:]) {
        try png.write(to: URL(fileURLWithPath: CommandLine.arguments[previewIndex + 1]))
    }
} else if CommandLine.arguments.contains("--localization-test") {
    let languageCases: [([String], String)] = [([], "en"), (["en-US", "zh-Hans"], "en"),
        (["fr-FR", "zh-Hans"], "en"), (["ja-JP"], "en"), (["zh"], "zh-Hans"),
        (["zh-CN"], "zh-Hans"), (["zh-SG"], "zh-Hans"), (["zh-Hans-TW"], "zh-Hans"),
        (["zh-TW"], "zh-Hant"), (["zh_HK"], "zh-Hant"), (["zh-Hant-CN"], "zh-Hant")]
    for (languages, expected) in languageCases { precondition(L10n.language(for: languages) == expected) }
    let keys = ["no_battery", "charging", "fully_charged", "plugged_in", "on_battery", "time_to_full", "time_remaining", "show_percentage", "icon_theme", "launch_at_login", "login_approval", "about", "quit", "login_error_title", "login_error_body", "ok", "credits"]
    for language in ["en", "zh-Hans", "zh-Hant"] {
        for key in keys + IconTheme.allCases.map(\.labelKey).filter({ !$0.isEmpty }) + ThemeLibrary.localizationKeys {
            precondition(L10n.text(key, language: language) != key, "Missing translation: \(language)/\(key)")
        }
    }
    precondition(L10n.duration(minutes: 65, charging: true, language: "en") == "About 1 h 5 min until full")
    precondition(L10n.duration(minutes: 65, charging: false, language: "zh-Hans") == "预计剩余 1小时5分钟")
    precondition(L10n.text("quit", language: "unsupported") == "Quit")
    print("PASS: language selection, translation resources and duration formatting")
    print("Language: \(L10n.currentLanguage); Menu: \(L10n.text("show_percentage")) / \(L10n.text("quit"))")
} else if CommandLine.arguments.contains("--self-test") {
    // 覆盖两个状态边界、充电优先级，以及接电但未充电的情况。
    var cases: [(BatteryState, String)] = [(.unavailable, "unknown")]
    for (percent, mood) in [(0, "low"), (20, "low"), (21, "normal"), (79, "normal"), (80, "high"), (100, "high")] {
        cases.append((BatteryState(percent: percent, charging: false, pluggedIn: false, minutes: nil), mood))
        cases.append((BatteryState(percent: percent, charging: true, pluggedIn: true, minutes: nil), "charging"))
        cases.append((BatteryState(percent: percent, charging: false, pluggedIn: true, minutes: nil), mood))
    }
    for (state, expected) in cases { precondition(state.mood == expected) }
    // 所有 16 种开关组合：仅充电、有电池、未休眠、未减少动态效果时允许运行。
    for mask in 0..<16 {
        let enabled = ChargingAnimation.enabled(charging: mask & 1 != 0, hasBattery: mask & 2 != 0,
            sleeping: mask & 4 != 0, reduceMotion: mask & 8 != 0)
        precondition(enabled == (mask == 3))
    }
    for tick in 1...12 {
        precondition(ChargingAnimation.frame(at: tick) == tick % 2)
        precondition(ChargingAnimation.shouldBlink(at: tick) == [6, 12].contains(tick))
    }
    print("PASS: animation eligibility (16 combinations), frame alternation and blink cadence")
    precondition(Set(IconTheme.allCases.map(\.rawValue)).count == IconTheme.allCases.count)
    precondition(IconTheme(rawValue: "removed-theme") == nil)
    for theme in IconTheme.allCases { precondition(IconTheme(rawValue: theme.rawValue) == theme) }
    print("PASS: \(IconTheme.allCases.count) icon themes")
    let actual = BatteryState.read()
    if let percent = actual.percent { precondition((0...100).contains(percent)) }
    print("PASS: \(cases.count) state cases; power source read: \(actual.percent.map(String.init) ?? "unavailable")")
} else {
    // [AppKit] 获取应用单例，设置代理和后台菜单栏模式，并启动事件循环。
    // AppDelegate 是我们自己的类；app.run() 是 AppKit API。
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
