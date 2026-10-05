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

`1.0.0` 起为稳定版本。之后不兼容的变更升 MAJOR，向下兼容的新功能升 MINOR，修复升 PATCH。

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

## 交互先在客户端截断

用户做不到的事，界面上就不要做成能点、能滑、能选。不要先发出请求，再把服务端的拒绝原样弹出来。

服务端仍然校验，用来挡住旧客户端和直接调接口。那是兜底，不是界面。客户端在发出之前就该知道结果，并把入口拿掉或让手势停住：

- 点不动：不要绑点击，也不要做成按钮
- 滑不动：这个方向没有动作时，卡片不跟着手指走
- 选不了：菜单里不出现这一项；目标不行时该项不可选
- 写不了：输入框只读

各状态只留能成功的操作：

| 状态 | 界面上能做的 |
|---|---|
| 任务池 | 改标题和过程小记；优先级可以是高、中、低、无、提醒。普通任务右滑进聚焦，提醒不能。左滑删除。可以换空间 |
| 聚焦 | 改标题和过程小记。普通任务只能在高、中、低之间改优先级。提醒不能改优先级、不能改时间、不能左滑回任务池。右滑完成。换空间时，对方聚焦已满的空间不可选 |
| 完成 | 只能左滑回任务池。详情只读 |
| 归档 | 只读 |

聚焦名额满了时，右滑不要把任务送进聚焦，用客户端自己的说明，不要展示服务端那句拒绝。提醒时间、crontab 这类填错了的内容，在选择器里拦住。

登录密码不对、网络失败，客户端事先无法判断，可以说明失败原因。

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

网页端固定请求当前 origin，不提供 API 地址设置。没有注册，登录只填密码。
跑 `./start.sh` 后，浏览器打开网页。第一次打开会让你设一个密码并再确认一次。

改完代码提 PR 前先跑一遍：

```bash
cd app && flutter analyze && flutter test
cd server && npm test
```

提醒循环的计算在 `server/src/tasks/reminder-time.ts`，crontab 在 `server/src/clock/cron.ts`，农历换算在 `server/src/clock/lunar.ts`（客户端 `app/lib/utils/` 下有同一套）。聚焦里提醒置顶、任务池里提醒垫底，排序在 `priority-order.ts` / `app/lib/ui/task_sort.dart`。
