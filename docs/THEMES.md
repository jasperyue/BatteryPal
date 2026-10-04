# 扩展菜单栏主题

## 文件职责

- `Sources/BatteryState.swift`：系统电源快照、low/normal/high/charging 状态规则及动画节奏。
- `Sources/AppDelegate.swift`：菜单栏、系统事件、偏好和共享动画定时器/缓存。
- `Sources/Themes/IconTheme.swift`：渲染协议、稳定 ID 和主题注册表。
- `Sources/Themes/BatteryTheme.swift`：电池主题绘图。
- `Sources/Themes/PineappleTheme.swift`：菠萝主题绘图。
- `Sources/Themes/SVGThemeAssets.swift`：SVG 文件加载、用户资源覆盖和缓存。
- `Sources/Themes/PineappleFallbackArt.swift`：系统 SVG 解码不可用时的兼容绘图。
- `Resources/Themes/pineapple/`：运行时菠萝 SVG 资源，构建时复制进 App。
- `Sources/main.swift`：启动及状态测试、语言测试、主题预览入口。

## 添加主题

1. 在 `Sources/Themes/` 添加 `YourTheme.swift`，实现 `IconThemeRenderer.image(_:ink:boltOpacity:blink:)`。仅处理绘图，不访问系统电源、不持有计时器。
2. 在 `IconTheme` 中定义唯一、稳定的 ID，关联渲染器，再加入 `allCases`。不要重命名已有 ID，否则已保存的用户选择会回退。
3. 在三个 `Resources/*.lproj/Localizable.strings` 中添加 `labelKey` 对应译文。
4. 运行 `bash scripts/build.sh`。菜单、预览及翻译测试会自动读取注册表，无需分别新增 switch 分支。
5. 使用 `dist/Battery Pie.app/Contents/MacOS/BatteryPie --render-preview preview.png` 检查实际尺寸与明暗背景。

## 渲染约定

- 输出 28×18 点的模板 NSImage；支持传入的 ink，以便生成明暗预览。
- 支持 low、normal、high、charging、unknown 五种状态；不在主题中重复电量阈值规则。
- 充电时使用 boltOpacity 和 blink 绘制动画帧，复用统一的三帧缓存。
- 所有 NSGraphicsContext 状态改变必须成对保存/恢复，不污染其他主题。
- 新主题的源码会被构建脚本自动纳入编译。

菠萝主题采用 OpenDesign 方案 A「圆润可爱」：圆润果身、短叶冠、边缘纹理和独立表情；右侧闪电亮暗交替，双眼每 6 秒闭合 0.15 秒。原始设计稿保存在 `docs/pineapple-a/`。

## 运行时 SVG 主题

应用启动后首次使用菠萝主题时按需加载 SVG。原生 `NSImage(data:)` 解码，单色轮廓的 alpha 用作模板遮罩；电量轨道由 Swift 独立绘制，避免 SVG 内固定电量。SVG 本身不负责动画。

文件名固定为 `low.svg`、`normal.svg`、`high.svg`、`unknown.svg`、`charging-frame-1.svg`（亮）、`charging-frame-2.svg`（35% 闪电）和 `charging-frame-3.svg`（眨眼）。使用 28×18 的 viewBox，透明背景，轮廓应保持单色；`currentColor` 加载时归一为黑色。充电参数 1 / 0.35 / blink 对应这三个离散帧。

自定义图标放在 `~/Library/Application Support/Battery Pie/Themes/pineapple/`。可以只覆盖部分文件，其余使用 App 内置文件；无效文件也回退到内置文件。SVG 缓存持续到退出应用，修改后重开即可加载；无需改变应用包或重新编译。不要在 SVG 中放电量轨道，底部 y=16.5 区域由应用绘制。

系统无法解码 SVG 时，使用已有 A 版原生矢量路径兼容回退，最低系统要求仍为 macOS 13。原生加载已在 macOS 15.7.9 验证，尚未在 macOS 13/14 机器上验证 SVG 解码能力；不依赖私有 SVG 类或 WebView。

运行 `bash scripts/build.sh` 后可执行 `bash scripts/test-svg-theme.sh`。测试要求原生 SVG 解码成功，覆盖七个打包资源、缓存、三帧实际像素差异、明暗模板色、电量轨道、自定义文件覆盖、无效文件回退与兼容路径。此测试需能访问 AppKit 绘图环境。
