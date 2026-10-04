# Battery Pal

一个原生 macOS 菜单栏电池小工具。灵感来自 Battery Buddy，独立实现，未使用其源码、名称或图像资源。

## 功能

- 原创矢量电池表情：low（0–20%）疲惫、normal（21–79%）微笑、high（80–100%）笑眼、charging 眨眼配闪电；充电状态优先于电量区间；下方细线表示电量。
- 实时读取内置电池，监听系统电源变化，唤醒后刷新，无定时轮询。
- 可切换电量百分比并保存偏好。
- 菜单显示供电状态、系统提供的预计剩余/充满时间。
- 使用系统 SMAppService 设置登录启动，默认关闭。
- 模板图标随菜单栏明暗自动适配；没有内置电池时显示问号。
- 充电动画：闪电每秒亮暗切换，每 6 秒眨眼 0.15 秒；复用三张缓存图像。停止充电、屏幕/整机休眠或系统开启“减少动态效果”时停止动画。
- 无网络、无第三方依赖、无遥测。

## 运行

要求 macOS 13 或更新版本。双击 `dist/Battery Pal.app` 即可运行，图标出现在菜单栏，不显示 Dock 图标。若菜单栏空间不足，请先腾出空间。

建议将 App 拖入 `/Applications` 后再从菜单中启用登录启动。它会新增一个菜单栏图标；可自行在系统设置中关闭系统自带电池图标。

## 编译

需要 Xcode 或包含 Swift 的 Command Line Tools：

```sh
bash scripts/build.sh
open "dist/Battery Pal.app"
```

脚本为当前机器架构编译，最低系统版本 macOS 13，生成本地 ad-hoc 签名。交付的二进制为 Apple Silicon 版本；Intel Mac 可在本机重新编译。源码只有 `Sources/main.swift`，可直接使用编辑器维护，不依赖 Xcode 工程或包管理器。

## 验证与限制

构建时会验证低电量边界、充电优先级、无电池状态及真实电源读取。运行中的菜单交互、不同外观和登录启动仍应在目标 Mac 上验证。系统没有提供时间估算时不会显示估算值。

本地构建未使用 Developer ID 签名或 Apple 公证。可以直接分享该版本；若希望减少首次打开时的安全拦截，可另行使用 Developer ID 签名并提交 Apple 公证。更新通过 Homebrew 或手动替换 App 完成。本项目不控制充电上限。

许可证：MIT，见 LICENSE。

## 下载与 Homebrew

从 [GitHub Releases](https://github.com/jasperyue/BatteryPal/releases) 下载 DMG，将 App 拖入 Applications。
当前发布包支持 Apple Silicon / macOS 13+。

发布 Homebrew tap 后，可使用：

```sh
brew install --cask jasperyue/tap/battery-pal
brew upgrade --cask battery-pal
```

此版本未经过 Apple 公证。首次打开若被拦截，请确认来源可信，再使用系统设置 → 隐私与安全性 → 仍要打开。
Homebrew 安装不会跳过 macOS 的安全检查。

## 制作 DMG

```sh
bash scripts/package-dmg.sh
```

生成的 DMG 和 SHA-256 文件在 `dist/` 中。DMG 包含 App、Applications 快捷链接和安装说明。
版本号目前在 `scripts/build.sh` 的 Info.plist 中设置；发布新版时也需同步关于面板及发布说明。
