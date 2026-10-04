## Changes / 更新

- Renamed the app from Battery Pal to Battery Pie across the app, bundle identifier, download and Homebrew cask.
- No functional changes: the same menu bar battery faces, charging animation, localization and login item behavior.

- 应用从 Battery Pal 更名为 Battery Pie，覆盖 App 名称、Bundle 标识、下载文件名与 Homebrew Cask。
- 功能保持不变：菜单栏电池表情、充电动画、多语言与登录启动行为一致。

Requires Apple Silicon and macOS 13+. Quit the older app before replacing it.

```sh
brew update
brew upgrade --cask battery-pie
```

The app is ad-hoc signed and not notarized by Apple. If macOS blocks first launch and you trust the source, use System Settings → Privacy & Security → Open Anyway.
本版本使用本地签名，未经过 Apple 公证。首次启动如被拦截，确认来源后可在「系统设置 → 隐私与安全性」选择「仍要打开」。
