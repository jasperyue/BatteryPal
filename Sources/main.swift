// Swift 的 import 将模块公开的名称引入当前文件，因此可直接写 NSImage、SMAppService，
// 不必每次写 AppKit.NSImage 或 ServiceManagement.SMAppService。
import AppKit             // macOS UI：菜单栏、菜单、图像绘制、应用生命周期。
import IOKit.ps           // IOKit 的电源子模块：IOPS… 函数及 kIOPS… 常量。
import ServiceManagement // 登录启动：SMAppService。

// 其他名称的来源（经上述框架的依赖/重导出在本文件中可用）：
// Foundation：NSObject、NSObjectProtocol、Notification、UserDefaults、NSString、
// NSAttributedString、URL，以及 NSPoint / NSSize / NSRect 这些几何别名。
// CoreFoundation：CFTypeRef、CFRunLoopSource、CFRunLoop… 函数。
// CGFloat 是 Core Foundation/Core Graphics 使用的标量类型。
// Swift 标准库：String、Int、Bool、Array、CommandLine、Unmanaged、min/max 等。
// BatteryState、BatteryArt、AppDelegate、refresh()、add() 等则是本项目自己定义的。
// 注意：NS 前缀不代表全部属于 AppKit，例如 UserDefaults/NSString 属于 Foundation。

struct BatteryState {
    let percent: Int?
    let charging: Bool
    let pluggedIn: Bool
    let minutes: Int?
    static let unavailable = BatteryState(percent: nil, charging: false, pluggedIn: false, minutes: nil)
    var mood: String {
        guard let percent else { return "unknown" }
        if charging { return "charging" }
        // 状态优先级：charging > low (0–20) > normal (21–79) > high (80–100)。
        if percent <= 20 { return "low" }
        if percent >= 80 { return "high" }
        return "normal"
    }
    static func read() -> BatteryState {
        // [IOKit.ps] 获取电源快照和电源列表；下面的 CFTypeRef 来自 CoreFoundation。
        // takeRetainedValue() 是 Swift Unmanaged 的方法，接管 Copy 返回值的所有权。
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef]
        else { return .unavailable }
        for source in sources {
            // [IOKit.ps] 获取单个电源的字典；所有 kIOPS… 常量也是该子模块定义的键/值。
            guard let info = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any],
                  info[kIOPSTypeKey] as? String == kIOPSInternalBatteryType,
                  let current = info[kIOPSCurrentCapacityKey] as? Int,
                  let max = info[kIOPSMaxCapacityKey] as? Int, max > 0 else { continue }
            let charging = info[kIOPSIsChargingKey] as? Bool ?? false
            let plugged = info[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue
            let time = info[charging ? kIOPSTimeToFullChargeKey : kIOPSTimeToEmptyKey] as? Int
            return BatteryState(percent: min(100, Swift.max(0, Int(Double(current) / Double(max) * 100))),
                                charging: charging, pluggedIn: plugged, minutes: time.flatMap { $0 > 0 ? $0 : nil })
        }
        return .unavailable
    }
}

// 纯状态规则，便于验证：只有可见、正在充电且允许动态效果时才启动计时器。
enum ChargingAnimation {
    static func enabled(charging: Bool, hasBattery: Bool, sleeping: Bool, reduceMotion: Bool) -> Bool {
        charging && hasBattery && !sleeping && !reduceMotion
    }
    static func frame(at tick: Int) -> Int { tick % 2 } // 0 = 明亮，1 = 柔和。
    static func shouldBlink(at tick: Int) -> Bool { tick > 0 && tick % 6 == 0 }
}

enum BatteryArt {
    // [AppKit] 用统一圆头线条绘制五官；ink 参数仅供深浅色预览使用。
    // 菜单栏仍然使用模板图像，由系统决定最终颜色。
    static func image(_ state: BatteryState, ink: NSColor = .black, boltOpacity: CGFloat = 1, blink: Bool = false) -> NSImage {
        // [AppKit] 以原来的 38×22 坐标绘图，等比缩到 28×18 点画布并垂直居中。
        // 所有表情和缓存动画帧使用相同变换，避免切换状态时尺寸跳动。
        let image = NSImage(size: NSSize(width: 28, height: 18), flipped: false) { _ in
            NSGraphicsContext.saveGraphicsState()
            defer { NSGraphicsContext.restoreGraphicsState() }
            let scale: CGFloat = 28.0 / 38.0
            let transform = NSAffineTransform()
            transform.translateX(by: 0, yBy: (18 - 22 * scale) / 2)
            transform.scale(by: scale)
            transform.concat()
            NSGraphicsContext.current?.shouldAntialias = true
            ink.setStroke()
            ink.setFill()
            func path(_ points: [NSPoint], width: CGFloat = 1.2) {
                let p = NSBezierPath()
                p.lineWidth = width
                p.lineCapStyle = .round
                p.lineJoinStyle = .round
                p.move(to: points[0])
                for point in points.dropFirst() { p.line(to: point) }
                p.stroke()
            }
            func curve(_ start: NSPoint, _ c1: NSPoint, _ c2: NSPoint, _ end: NSPoint, width: CGFloat = 1.2) {
                let p = NSBezierPath()
                p.lineWidth = width
                p.lineCapStyle = .round
                p.move(to: start)
                p.curve(to: end, controlPoint1: c1, controlPoint2: c2)
                p.stroke()
            }
            // [AppKit] NSBezierPath：柔和圆角外壳，以及独立的小电池触点。
            let shell = NSBezierPath(roundedRect: NSRect(x: 1.5, y: 3.5, width: 30, height: 16), xRadius: 4.5, yRadius: 4.5)
            shell.lineWidth = 1.35
            shell.stroke()
            NSBezierPath(roundedRect: NSRect(x: 33, y: 8.5, width: 2.2, height: 6), xRadius: 1.1, yRadius: 1.1).fill()
            // 底部轻量电量轨道：不抢表情的视觉重点。
            if let percent = state.percent {
                ink.withAlphaComponent(0.18).setStroke()
                path([NSPoint(x: 7, y: 1), NSPoint(x: 26, y: 1)], width: 1.2)
                ink.setStroke()
                if percent > 0 {
                    path([NSPoint(x: 7, y: 1), NSPoint(x: 7 + 19 * CGFloat(percent) / 100, y: 1)], width: 1.2)
                }
            }
            switch state.mood {
            case "low":
                // 低电量：下垂的眼睑、小小的叹气嘴。
                curve(NSPoint(x: 8, y: 13), NSPoint(x: 9, y: 11.6), NSPoint(x: 11, y: 11.6), NSPoint(x: 12, y: 12.2))
                curve(NSPoint(x: 21, y: 12.2), NSPoint(x: 22, y: 11.6), NSPoint(x: 24, y: 11.6), NSPoint(x: 25, y: 13))
                let mouth = NSBezierPath(ovalIn: NSRect(x: 15, y: 7, width: 3, height: 2.5))
                mouth.lineWidth = 1
                mouth.stroke()
            case "normal":
                // 普通电量：短椭圆眼睛和含蓄微笑。
                for x: CGFloat in [10, 23] {
                    NSBezierPath(ovalIn: NSRect(x: x - 0.95, y: 11.4, width: 1.9, height: 2.8)).fill()
                }
                curve(NSPoint(x: 13.5, y: 9.5), NSPoint(x: 15, y: 7.3), NSPoint(x: 18, y: 7.3), NSPoint(x: 19.5, y: 9.5))
            case "high":
                // 高电量：弯弯笑眼、张开的笑嘴和淡淡脸颊。
                for x: CGFloat in [10, 23] {
                    curve(NSPoint(x: x - 2, y: 12), NSPoint(x: x - 1, y: 15), NSPoint(x: x + 1, y: 15), NSPoint(x: x + 2, y: 12))
                }
                let mouth = NSBezierPath()
                mouth.move(to: NSPoint(x: 13.3, y: 10))
                mouth.line(to: NSPoint(x: 19.7, y: 10))
                mouth.curve(to: NSPoint(x: 13.3, y: 10), controlPoint1: NSPoint(x: 19, y: 5.4), controlPoint2: NSPoint(x: 14, y: 5.4))
                mouth.close()
                mouth.fill()
                ink.withAlphaComponent(0.3).setStroke()
                for x: CGFloat in [7.5, 24] { path([NSPoint(x: x, y: 9), NSPoint(x: x + 1.5, y: 9)], width: 1) }
            case "charging":
                // 充电：左眼眨眼，右眼是小闪电；和 high 明确区分。
                if blink {
                    path([NSPoint(x: 8, y: 12), NSPoint(x: 12, y: 12)])
                } else {
                    curve(NSPoint(x: 8, y: 12), NSPoint(x: 9, y: 14), NSPoint(x: 11, y: 14), NSPoint(x: 12, y: 12))
                }
                let bolt = NSBezierPath()
                bolt.move(to: NSPoint(x: 24, y: 16.2))
                for point in [NSPoint(x: 20.5, y: 12.2), NSPoint(x: 23, y: 12.2), NSPoint(x: 21.5, y: 8.9), NSPoint(x: 26, y: 13.5), NSPoint(x: 23.5, y: 13.5)] { bolt.line(to: point) }
                bolt.close()
                ink.withAlphaComponent(boltOpacity).setFill()
                bolt.fill()
                ink.setFill()
                curve(NSPoint(x: 13.5, y: 9.5), NSPoint(x: 14.5, y: 6.5), NSPoint(x: 17.5, y: 6.5), NSPoint(x: 18.5, y: 9.5))
            default:
                // [Foundation + AppKit] NSString 的绘制扩展显示无电池状态。
                ("?" as NSString).draw(at: NSPoint(x: 13, y: 5), withAttributes: [.font: NSFont.systemFont(ofSize: 12, weight: .medium), .foregroundColor: ink])
            }
            return true
        }
        image.isTemplate = true
        return image
    }
}

// [Foundation] NSObject 是基类；[AppKit] 两个 Delegate 协议让系统回调应用/菜单事件。
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var item: NSStatusItem! // [AppKit] 一个菜单栏项目。
    private var notification: CFRunLoopSource? // [CoreFoundation] 保存电源通知事件源。
    private var state = BatteryState.unavailable
    private var observers: [NSObjectProtocol] = []
    private var animationTimer: Timer? // [Foundation] 每秒一次，不查询电源，只切换缓存图像。
    private var blinkEnd: DispatchWorkItem? // [Dispatch] 眨眼 0.15 秒后的单次复原任务。
    private var chargingFrames: [NSImage] = []
    private var cachedPercent: Int?
    private var animationTick = 0
    private var isBlinking = false
    private var screensSleeping = false
    private var systemSleeping = false
    // [Foundation] UserDefaults 持久化用户设置，并非 AppKit 的 UI API。
    private var showPercentage: Bool {
        get { UserDefaults.standard.object(forKey: "showPercentage") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "showPercentage") }
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        // [AppKit] NSStatusBar 创建 NSStatusItem；NSMenu 是点击图标时展开的菜单。
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.menu = NSMenu()
        item.menu?.delegate = self
        refresh()
        // [IOKit.ps] 注册电源状态变化回调；该函数返回 CoreFoundation 事件源。
        // [Swift] Unmanaged 将当前对象转换为 C 回调携带的上下文指针。
        self.notification = IOPSNotificationCreateRunLoopSource({ context in
            guard let context else { return }
            Unmanaged<AppDelegate>.fromOpaque(context).takeUnretainedValue().refresh()
        }, Unmanaged.passUnretained(self).toOpaque())?.takeRetainedValue()
        // [CoreFoundation] 将事件源接入主线程事件循环，开始接收通知。
        if let source = self.notification { CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes) }
        // [AppKit] NSWorkspace 提供系统唤醒事件；addObserver 属于 Foundation 的 NotificationCenter。
        let center = NSWorkspace.shared.notificationCenter
        // [AppKit] 屏幕和整机休眠分别记录，避免电源回调在休眠期间重新启用动画。
        for name in [NSWorkspace.screensDidSleepNotification, NSWorkspace.screensDidWakeNotification,
                     NSWorkspace.willSleepNotification, NSWorkspace.didWakeNotification,
                     NSWorkspace.accessibilityDisplayOptionsDidChangeNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                guard let self else { return }
                switch note.name {
                case NSWorkspace.screensDidSleepNotification: self.screensSleeping = true
                case NSWorkspace.screensDidWakeNotification: self.screensSleeping = false
                case NSWorkspace.willSleepNotification: self.systemSleeping = true
                case NSWorkspace.didWakeNotification: self.systemSleeping = false
                default: break
                }
                self.refresh()
            })
        }
    }
    func applicationWillTerminate(_ notification: Notification) {
        stopAnimation()
        // [CoreFoundation] 应用退出时移除事件源；下面 removeObserver 是 Foundation API。
        if let source = self.notification { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        for observer in observers { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
    }
    func refresh() {
        state = .read()
        // [AppKit] item.button 是 NSStatusBarButton；image/title/font/toolTip 及无障碍设置
        // 都是在更新 AppKit 控件。省略类型的 .monospacedDigitSystemFont 实际是 NSFont 方法。
        guard let button = item?.button else { return }
        updateAnimation()
        button.imagePosition = .imageLeading
        button.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        button.title = showPercentage ? " \(state.percent.map { "\($0)%" } ?? "—")" : ""
        button.toolTip = "Battery Pie · \(statusText)"
        button.setAccessibilityLabel("Battery Pie · \(statusText)")
    }
    private func updateAnimation() {
        let enabled = ChargingAnimation.enabled(charging: state.charging, hasBattery: state.percent != nil,
            sleeping: screensSleeping || systemSleeping,
            reduceMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion) // [AppKit]
        guard enabled else {
            stopAnimation()
            item.button?.image = BatteryArt.image(state)
            return
        }
        // 仅在电量变化时重建三张缓存帧；秒级刷新直接复用图像。
        if chargingFrames.isEmpty || cachedPercent != state.percent {
            cachedPercent = state.percent
            chargingFrames = [BatteryArt.image(state), BatteryArt.image(state, boltOpacity: 0.35),
                              BatteryArt.image(state, blink: true)]
        }
        showAnimationFrame()
        guard animationTimer == nil else { return }
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.animationTick = self.animationTick % 6 + 1
            self.isBlinking = ChargingAnimation.shouldBlink(at: self.animationTick)
            self.showAnimationFrame()
            if self.isBlinking {
                let end = DispatchWorkItem { [weak self] in
                    guard let self, self.animationTimer != nil else { return }
                    self.isBlinking = false
                    self.showAnimationFrame()
                    self.blinkEnd = nil
                }
                self.blinkEnd = end
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: end)
            }
        }
        timer.tolerance = 0.2 // [Foundation] 允许系统合并唤醒，减少不必要的调度。
        RunLoop.main.add(timer, forMode: .common)
        animationTimer = timer
    }
    private func showAnimationFrame() {
        guard chargingFrames.count == 3 else { return }
        item.button?.image = chargingFrames[isBlinking ? 2 : ChargingAnimation.frame(at: animationTick)]
    }
    private func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
        blinkEnd?.cancel()
        blinkEnd = nil
        animationTick = 0
        isBlinking = false
    }
    private var statusText: String {
        guard let percent = state.percent else { return L10n.text("no_battery") }
        let key = state.charging ? "charging" : (state.pluggedIn ? (percent == 100 ? "fully_charged" : "plugged_in") : "on_battery")
        let status = L10n.text(key)
        return "\(percent)% · \(status)"
    }
    // [AppKit] NSMenuDelegate 回调；菜单项的增删、分隔线、勾选状态都由 AppKit 处理。
    func menuWillOpen(_ menu: NSMenu) {
        refresh()
        menu.removeAllItems()
        add("Battery Pie", to: menu)
        add(statusText, to: menu)
        if let minutes = state.minutes, state.charging || !state.pluggedIn {
            add(L10n.duration(minutes: minutes, charging: state.charging), to: menu)
        }
        menu.addItem(.separator())
        let percent = add(L10n.text("show_percentage"), action: #selector(togglePercentage), to: menu)
        percent.state = showPercentage ? .on : .off
        // [ServiceManagement] 查询主 App 的登录启动状态。
        let service = SMAppService.mainApp
        let login = add(L10n.text(service.status == .requiresApproval ? "login_approval" : "launch_at_login"), action: #selector(toggleLogin), to: menu)
        login.state = service.status == .enabled || service.status == .requiresApproval ? .on : .off
        menu.addItem(.separator())
        add(L10n.text("about"), action: #selector(about), to: menu)
        let quit = add(L10n.text("quit"), action: #selector(quit), to: menu)
        quit.keyEquivalent = "q"
    }
    @discardableResult private func add(_ title: String, action: Selector? = nil, to menu: NSMenu) -> NSMenuItem {
        // [AppKit] 创建菜单项，target/action 指定点击后调用本对象的哪个方法。
        // #selector 和 @objc 属于 Swift 与 Objective-C 的互操作语法，不是某个 UI 库函数。
        let entry = NSMenuItem(title: title, action: action, keyEquivalent: "")
        entry.target = self
        menu.addItem(entry)
        return entry
    }
    @objc private func togglePercentage() { showPercentage.toggle(); refresh() }
    @objc private func toggleLogin() {
        do {
            // [ServiceManagement] register 启用登录启动，unregister 关闭；
            // openSystemSettingsLoginItems 打开系统的登录项设置页面。
            switch SMAppService.mainApp.status {
            case .enabled: try SMAppService.mainApp.unregister()
            case .requiresApproval: SMAppService.openSystemSettingsLoginItems()
            default: try SMAppService.mainApp.register()
            }
        } catch {
            // [AppKit] NSAlert 显示对话框；NSApp 是当前 NSApplication 的全局引用。
            let alert = NSAlert()
            alert.messageText = L10n.text("login_error_title")
            // 系统错误详情来自系统框架；App 自己提供的说明按所选语言显示。
            alert.informativeText = L10n.text("login_error_body") + "\n" + error.localizedDescription
            alert.addButton(withTitle: L10n.text("ok"))
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
        }
    }
    // [AppKit] 激活应用并显示系统标准“关于”面板。
    @objc private func about() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [.applicationName: "Battery Pie", .applicationVersion: "1.1.0", .credits: NSAttributedString(string: L10n.text("credits"))])
    }
    // [AppKit] 请求结束应用。
    @objc private func quit() { NSApp.terminate(nil) }
}

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
    // [AppKit] 同一组矢量图分别在明暗背景绘制；每列同时展示放大图与实际 28×18 点尺寸。
    let preview = NSImage(size: NSSize(width: 1000, height: 500), flipped: false) { _ in
        for dark in [false, true] {
            let base: CGFloat = dark ? 0 : 250
            let ink: NSColor = dark ? .white : NSColor(white: 0.12, alpha: 1)
            (dark ? NSColor(white: 0.10, alpha: 1) : NSColor(white: 0.97, alpha: 1)).setFill()
            NSRect(x: 0, y: base, width: 1000, height: 250).fill()
            for (index, state) in states.enumerated() {
                let x = CGFloat(index * 200)
                let icon = BatteryArt.image(state, ink: ink)
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
    let keys = ["no_battery", "charging", "fully_charged", "plugged_in", "on_battery", "time_to_full", "time_remaining", "show_percentage", "launch_at_login", "login_approval", "about", "quit", "login_error_title", "login_error_body", "ok", "credits"]
    for language in ["en", "zh-Hans", "zh-Hant"] {
        for key in keys {
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
