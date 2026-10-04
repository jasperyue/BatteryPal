## Changes / 更新

- The pineapple theme now loads SVG artwork at runtime, preserving the rounded A design.
- Customize individual states and charging frames in `~/Library/Application Support/Battery Pie/Themes/pineapple/`, then restart the app. No Swift changes or rebuild required.
- SVG assets are cached; the battery track remains driven by live battery data.
- Invalid custom files fall back to bundled artwork. Systems unable to decode SVG retain the original native vector renderer.

- 菠萝主题改为运行时加载 SVG，保留圆润 A 版造型。
- 可在用户主题目录替换各状态和充电帧，重开应用即可生效，无需修改 Swift 或重新编译。
- SVG 缓存避免动画逐帧读文件，电量轨道仍跟随真实电量。
- 无效自定义文件回退到内置资源；无法解码 SVG 的系统保留原生矢量绘图。

Requires Apple Silicon / macOS 13+. Native SVG rendering verified on macOS 15.7.9; older systems retain a drawing fallback.
需要 Apple Silicon / macOS 13+。原生 SVG 渲染已在 macOS 15.7.9 验证；旧系统保留绘图回退。

Quit Battery Pie before upgrading. The app is ad-hoc signed and not notarized by Apple.
升级前请退出 Battery Pie。应用使用本地签名，未经过 Apple 公证。
