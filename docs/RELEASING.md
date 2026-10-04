# 发布流程

## 一键发布

在 Apple Silicon Mac 上安装 GitHub CLI，运行 `gh auth login`。账号需要对 `jasperyue/BatteryPie` 和 `jasperyue/homebrew-tap` 拥有写权限。脚本使用当前登录账号，不存储 token。

1. 更新根目录 `VERSION`（例如 `1.2.0`）和 `BUILD_NUMBER`（每次递增）；应用关于面板自动读取构建版本。
2. 编写 `docs/RELEASE-v版本号.md`，提交全部源码，保持工作区干净。
3. 可运行 `bash scripts/release-homebrew.sh --dry-run` 查看发布计划。
4. 运行 `bash scripts/release-homebrew.sh`。

脚本自动构建并运行状态、主题、语言测试，制作并验证 DMG，推送当前分支与版本 tag，创建带资产的草稿 Release。下载远端 DMG 后核对 SHA-256 并验证磁盘映像，校验 cask 语法，再公开 Release，通过 GitHub Contents API 提交 tap 的版本和 SHA-256 更新。cask 的其他字段保持原样，不需要在本机修改相邻 tap 仓库。

两个仓库的更新不是原子操作。如果 Release 上传后或 tap 更新时失败，运行：

```sh
bash scripts/release-homebrew.sh --resume
```

续跑要求本机 HEAD 与远端 tag 指向相同提交。它下载已有资产继续验证，不重建或覆盖同版本 DMG；tap 已经匹配时不会重复提交。若草稿只上传了一部分资产，请先将原始 `dist/` 中缺失的资产上传到该草稿，再续跑；不要重新打包同版本。tap 已存在更新版本或同版本不同校验值时会拒绝更新。

执行脚本就是发布操作，会推送当前分支、创建 tag、公开 Release 并更新 tap。这里提供的脚本不会自动提交你的源码；先提交后发布，保证 tag 与二进制对应。

## 手动打包

```sh
bash scripts/package-dmg.sh
```

DMG 与校验文件位于 `dist/`。建议在发布前挂载并检查 App 与 Applications 链接，在目标 Mac 验证菜单交互。当前发布支持 arm64 / macOS 13+。

不要覆盖已公开发布的同版本 DMG：重新打包可能改变校验值，应发布新版本。本流程使用 ad-hoc 签名，不移除 quarantine，不关闭 macOS 安全检查。
