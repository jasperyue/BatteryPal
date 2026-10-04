## Changes / 更新

- Follow the preferred system/app language: Simplified or Traditional Chinese when Chinese is preferred; English for all other languages. Menus, battery status, time estimates and app messages are localized.
- Add a custom application icon for Finder, Launchpad and the About window, with Retina variants.
- Remove tracked IDE configuration while retaining local files.

- 根据系统或应用首选语言显示简体/繁体中文，其他语言默认英文；覆盖菜单、电池状态、时间估算及应用提示。
- 新增 Finder、启动台及关于窗口使用的应用图标，包含 Retina 尺寸。
- 停止跟踪 IDE 配置，本地文件保留。

Requires Apple Silicon and macOS 13+. Quit Battery Pal before replacing the app.

```sh
brew update
brew upgrade --cask battery-pal
```

The app is ad-hoc signed and not notarized by Apple. If macOS blocks first launch and you trust the source, use System Settings → Privacy & Security → Open Anyway.
本版本使用本地签名，未经过 Apple 公证。首次启动如被拦截，确认来源后可在「系统设置 → 隐私与安全性」选择「仍要打开」。
