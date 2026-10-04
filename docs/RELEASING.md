# 发布流程

1. 更新 `scripts/build.sh` 中的版本号和构建号，以及 `Sources/main.swift` 关于面板版本。
2. 编写新版本发布说明，运行 `bash scripts/package-dmg.sh`。
3. 挂载 DMG 检查 App 和 Applications 链接；在目标 Mac 验证运行。当前发布只支持 arm64。
4. 提交并推送源码，创建对应的 `v版本号` tag / GitHub Release，将 dist 中 DMG 和对应 `.sha256` 文件上传。
5. 更新相邻 `homebrew-tap/Casks/battery-pal.rb` 中的版本和 SHA-256，再提交并推送 tap。
6. 检查下载地址、校验值和 Homebrew Cask。不要覆盖已经公开发布的同版本 DMG：重新打包可能改变校验值，应发布新版本。

当前 GitHub 仓库：jasperyue/BatteryPal、jasperyue/homebrew-tap。
本流程不使用 Apple 付费开发者证书或公证，不移除 macOS quarantine，不关闭安全检查。
