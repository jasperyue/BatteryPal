import AppKit
import IOKit.ps
import ServiceManagement

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
    private var cachedTheme: IconTheme?
    private var animationTick = 0
    private var isBlinking = false
    private var screensSleeping = false
    private var systemSleeping = false
    // [Foundation] UserDefaults 持久化用户设置，并非 AppKit 的 UI API。
    private var showPercentage: Bool {
        get { UserDefaults.standard.object(forKey: "showPercentage") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "showPercentage") }
    }
    // [Foundation] 图标主题偏好：电池表情或菠萝，用原始值字符串持久化。
    private var iconTheme: IconTheme {
        get { IconTheme(rawValue: UserDefaults.standard.string(forKey: "iconTheme") ?? "") ?? .battery }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "iconTheme") }
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
            item.button?.image = BatteryArt.image(state, theme: iconTheme)
            return
        }
        // 仅在电量变化时重建三张缓存帧；秒级刷新直接复用图像。
        if chargingFrames.isEmpty || cachedPercent != state.percent || cachedTheme != iconTheme {
            cachedPercent = state.percent
            cachedTheme = iconTheme
            chargingFrames = [BatteryArt.image(state, theme: iconTheme),
                              BatteryArt.image(state, boltOpacity: 0.35, theme: iconTheme),
                              BatteryArt.image(state, blink: true, theme: iconTheme)]
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
        // 图标主题子菜单：列出所有主题并勾选当前项。
        let themeParent = NSMenuItem(title: L10n.text("icon_theme"), action: nil, keyEquivalent: "")
        let themeMenu = NSMenu()
        for theme in IconTheme.allCases {
            let entry = NSMenuItem(title: L10n.text(theme.labelKey), action: #selector(selectTheme), keyEquivalent: "")
            entry.target = self
            entry.representedObject = theme.rawValue
            entry.state = theme == iconTheme ? .on : .off
            themeMenu.addItem(entry)
        }
        themeParent.submenu = themeMenu
        menu.addItem(themeParent)
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
    @objc private func selectTheme(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String, let theme = IconTheme(rawValue: id) else { return }
        iconTheme = theme
        refresh()
    }
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
        NSApp.orderFrontStandardAboutPanel(options: [.applicationName: "Battery Pie", .applicationVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "", .credits: NSAttributedString(string: L10n.text("credits"))])
    }
    // [AppKit] 请求结束应用。
    @objc private func quit() { NSApp.terminate(nil) }
}
