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

docs: explain LAN Docker deployment

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
5. 推送 `v*.*.*` 标签后，`.github/workflows/release.yml` 只上传一个
   `FlowDo-vX.Y.Z.zip`：里面是 `docker-compose.yml`、服务端/网页端镜像（各带一个 `.id`）、
   根目录的 `start.sh` / `start.ps1`，以及 `DEPLOY.md`（包里叫 `README.md`），
   再用该版本的 changelog 创建 GitHub Release

也可以在 GitHub 网页上对已推送的标签起草 Release。

## 只做网页端

客户端只发布网页端，仓库里也只留 `app/web/` 一个平台目录。Android / iOS /
Windows / macOS / Linux 都不再维护，请不要再往回加平台目录或平台专属代码；
需要调某个桌面平台来调试是可以的，但那属于本地临时行为，别提交进来。

## 开发

本机一键起全套（需要 Flutter SDK）：仓库根目录的 `./start.sh` / `start.ps1`，
和发版包里是同一个脚本，放在源码目录时会先构建网页端和服务端镜像再 `docker compose up -d`，
然后等 API、网页端都 healthy。起来后网页端在 `http://127.0.0.1:8080`，API 在 `http://127.0.0.1:13000`。
只调客户端：`cd app && flutter pub get && flutter run -d chrome`。

### 不用 Docker 启动服务端

需要本机 PostgreSQL，库名和账号与 [server/.env.example](server/.env.example) 一致。

```bash
cd server
cp .env.example .env     # Windows 用 copy
npm install
npx prisma generate
npx prisma db push
npm run start:dev
```

API 监听 `0.0.0.0:3000`。正式部署时网页端 nginx 会同源反代 API；直接用
`flutter run -d chrome` 调试时，浏览器开发服务器没有这层代理，优先用完整 Docker
栈做联调。

### 网页端

先安装 [Flutter SDK](https://docs.flutter.dev/get-started/install)。国内建议配好镜像：

```
FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
PUB_HOSTED_URL=https://pub.flutter-io.cn
```

`app/web/` 已经在仓库里，不需要 `flutter create`：

```bash
cd app
flutter pub get
flutter run -d chrome
```

出发布产物，再打成 nginx 镜像：

```bash
cd app && flutter build web --release --no-web-resources-cdn && cd ..
docker build -f web/Dockerfile -t flowdo-web:latest .
```

`--no-web-resources-cdn` 一定要带上：默认的 CanvasKit 是从 `gstatic.com` 取的，
内网和连不上谷歌的网络会直接白屏或满屏方块。产物目录必须整个一起部署，
少了 `assets/`（字体、图标）或 `canvaskit/` 就是同一类故障。

网页端固定请求当前 origin，不提供 API 地址设置。账号也不通过网络注册，写在部署目录的
`.user` 里（一行一个「用户名 密码」），再跑 `./start.sh`。数据库以这个文件为准。

改完代码提 PR 前先跑一遍：

```bash
cd app && flutter analyze && flutter test
cd server && npm test
```
