# 参与指南

欢迎给 [随随办办 / FlowDo](https://github.com/ShuangqiLi/FlowDo) 提 issue 或 pull request。

## 提交信息（约定式提交）

本仓库使用 [Conventional Commits](https://www.conventionalcommits.org/zh-hans/v1.0.0/)。

```
<类型>[可选范围]: <简述>

[可选正文]

[可选脚注]
```

- 简述用英文或中文均可，一句说清「为什么 / 做了什么」，不要句号结尾
- 类型小写，后面紧跟冒号和空格
- 破坏性变更在类型后加 `!`，或在脚注写 `BREAKING CHANGE:`
- 不要附加 `Co-authored-by: Cursor` 或其他与改动无关的 trailer

### 类型

| 类型 | 用途 |
|---|---|
| `feat` | 新功能 |
| `fix` | 缺陷修复 |
| `docs` | 文档 |
| `style` | 格式（不影响逻辑） |
| `refactor` | 重构 |
| `perf` | 性能 |
| `test` | 测试 |
| `build` | 构建或依赖 |
| `ci` | CI |
| `chore` | 杂项（工具、仓库整理） |
| `revert` | 回滚 |

### 示例

```
feat: add swipe actions on inbox cards

fix(auth): show a friendly message for invalid credentials

docs: explain public HTTPS deploy with Caddy

feat(api)!: require focus before marking a task done

BREAKING CHANGE: TODO cannot transition directly to DONE
```

## 版本号（SemVer）

遵循 [Semantic Versioning 2.0.0](https://semver.org/lang/zh-CN/)：

- **MAJOR**：不兼容的 API / 数据 / 行为变更
- **MINOR**：向下兼容的新功能
- **PATCH**：向下兼容的问题修复

当前处于 `0.y.z`：尚未宣布稳定公开 API，行为仍可能变化。下一个功能版本可以是 `0.1.0`，纯修复是 `0.0.2`。

发布走 [GitHub Releases](https://github.com/ShuangqiLi/FlowDo/releases)，不用根目录脚本发版：

1. 更新 `VERSION`、`app/pubspec.yaml`、`server/package.json` 为同一 `x.y.z`
2. 在 `CHANGELOG.md` 顶部增加对应章节
3. 提交：`chore(release): vX.Y.Z`
4. 打标签并推送：`git tag -a vX.Y.Z -m "chore(release): vX.Y.Z"`，再 `git push origin vX.Y.Z`
5. 推送 `v*.*.*` 标签后，`.github/workflows/release.yml` 会构建并上传服务端
   Docker 包、Windows 客户端、Android APK、Web 客户端和 iOS IPA，再用该版本的
   changelog 创建 GitHub Release

也可以在 GitHub 网页上对已推送的标签起草 Release。

### iOS 安装包

Apple 不允许未签名的 IPA 装到真机上。CI 在 `macos-latest` 上打出
`FlowDo-client-ios-*.ipa`，**默认未签名**，方便用自己的证书重签，但不能直接
点开安装。

要打出可安装的包，需要：

1. 加入 [Apple Developer Program](https://developer.apple.com/programs/)
2. 在 Apple Developer 后台创建 App ID（`com.flowdo.app`）、发行证书和
   Ad Hoc / App Store 描述文件
3. 把 `.p12` 证书和 `.mobileprovision` 配到仓库 Secrets 后，再改 CI 为
   `flutter build ipa` 并带上导出选项（当前工作流尚未接入这些 Secrets）
4. 更稳妥的分发方式是 Xcode / Transporter 上传到 TestFlight，而不是把
   签名 IPA 放到公开 GitHub Release

没有开发者账号时，iPhone 请用 Web 客户端。

## 开发

本机服务端可用 `scripts/deploy.bat` / `./scripts/deploy.sh`，或直接 `docker compose up --build -d`。  
客户端：`cd app && flutter pub get && flutter run`。
