# 扩展菜单栏主题

## 文件职责

- `Sources/BatteryState.swift`：系统电源快照、low/normal/high/charging 状态规则及动画节奏。
- `Sources/AppDelegate.swift`：菜单栏、系统事件、偏好和共享动画定时器/缓存。
- `Sources/Themes/IconTheme.swift`：渲染协议、稳定 ID 和主题注册表。
- `Sources/Themes/BatteryTheme.swift`：电池主题绘图。
- `Sources/Themes/PineappleTheme.swift`：菠萝主题绘图。
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

菠萝主题采用 OpenDesign 方案 A「圆润可爱」：圆润果身、短叶冠、边缘纹理和独立表情；右侧闪电亮暗交替，双眼每 6 秒闭合 0.15 秒。原始 SVG 保存在 `docs/pineapple-a/`，Swift 渲染器按 28×18 坐标转换路径（包含二次曲线到三次曲线的转换）。未知状态保留空轨道和矢量问号。
