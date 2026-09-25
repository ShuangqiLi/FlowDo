# 随随办办 / FlowDo

随随办办，总会办完。  
Go with the flow, get it done.  
随随办办——无压力任务管理。服务端（NestJS + PostgreSQL）与客户端（Flutter）分离，个人账号空间，只管状态和优先级，不赶截止日期。

开源协议：[MIT](LICENSE) · 当前版本 [v0.0.4](CHANGELOG.md) · [参与指南](CONTRIBUTING.md) · [Releases](https://github.com/ShuangqiLi/FlowDo/releases)

## 功能

- 多用户注册登录（JWT）
- 任务池 → 聚焦 → 完成 → 归档
- 高 / 中 / 低优先级
- 可选正文随手记想法
- 每日「今日看看」
- 完成后按设置天数自动归档（默认 7 天）
- 归档只读，可手动删除；到期自动清掉（默认 30 天）
- Web / 手机 / PC 共用 Flutter，连同一 API
- 薄荷绿、雾霾蓝、暖橘色、淡紫色四套账号同步主题
- 可复用的 [FlowDo UI Kit](docs/UI_KIT.md)

## 下载与发版

[GitHub Releases](https://github.com/ShuangqiLi/FlowDo/releases) 提供分开的可执行产物：

- `FlowDo-server-docker-*.zip`：服务端 Docker 镜像和 PostgreSQL，解压后运行
  `start.ps1`（Windows）或 `start.sh`（macOS / Linux）
- `FlowDo-client-windows-x64-*.zip`：Windows 客户端，解压后运行 `FlowDo.exe`
- `FlowDo-client-android-*.apk`：Android 客户端安装包
- `FlowDo-client-ios-*.ipa`：iOS 客户端。默认是 **未签名** 包，不能直接装到
  iPhone / iPad；需要 Apple 开发者账号签名后才能安装（见
  [CONTRIBUTING.md](CONTRIBUTING.md)）
- `FlowDo-client-web-*.zip`：可部署到静态网站的 Web 客户端

版本号遵循 SemVer，从 `v0.0.1` 起。正式发布只走 GitHub Releases：更新
`VERSION`、`CHANGELOG.md` 与包版本后，打 `vX.Y.Z` 标签并推送，Actions
会构建上述产物并根据 changelog 创建 Release。细节见
[CONTRIBUTING.md](CONTRIBUTING.md)。

## 本机启动服务端

需要本机已安装并打开 [Docker Desktop](https://www.docker.com/products/docker-desktop/)。辅助脚本在 [`scripts/`](scripts/)，只用于本机或自建环境，不参与发版。

Windows（可双击 `scripts\deploy.bat`，或执行 `.\scripts\deploy.ps1`）：

```bat
scripts\deploy.bat
```

macOS / Linux：

```bash
chmod +x scripts/deploy.sh
./scripts/deploy.sh
```

脚本会准备镜像、构建并启动 PostgreSQL + API。就绪后：

- API：`http://127.0.0.1:3000`（仅本机）
- 健康检查：`GET /health`
- 同一局域网：把 App 的 API 填成 `http://<电脑局域网IP>:3000`

停掉：`docker compose down`

## 公网部署

`127.0.0.1` 只有这台电脑能访问。要给外网用，把项目放到一台有公网 IP 的服务器上（云主机即可）。

### 有域名（推荐，自动 HTTPS）

1. 域名加一条 **A 记录**，指到服务器公网 IP。
2. 安全组 / 防火墙放行 **80、443**。
3. 服务器安装 Docker 后，在仓库根目录执行：

```bash
chmod +x scripts/deploy-public.sh
DOMAIN=api.example.com JWT_SECRET='请换成很长的随机串' ./scripts/deploy-public.sh
```

就绪后 API 是 `https://api.example.com`。App 登录页把 API 地址改成这个。

也可以等价写成：

```bash
export DOMAIN=api.example.com
export JWT_SECRET='请换成很长的随机串'
docker compose -f docker-compose.yml -f docker-compose.public.yml up --build -d
```

公网模式不会把数据库端口暴露到外网。

### 只有公网 IP、暂时没有域名

本机辅助脚本同样会监听 `0.0.0.0:3000`。在服务器上用 `scripts/deploy.sh` / `scripts/deploy.bat` 启动后，外网可访问：

`http://<服务器公网IP>:3000`

安全组放行 **3000**。这是明文 HTTP，只适合自己临时用；有域名后请改用上面的 HTTPS 方式。不要把 `5432` 对公网开放。

## 不用 Docker 启动服务端

需要本机 PostgreSQL，库名/账号与 [server/.env.example](server/.env.example) 一致。

```bash
cd server
copy .env.example .env   # Windows
npm install
npx prisma generate
npx prisma db push
npm run start:dev
```

局域网手机访问：把 Flutter 设置里的 API 地址改成 `http://<电脑局域网IP>:3000`，并保证防火墙放行 3000 端口。API 已监听 `0.0.0.0`。

## Flutter 客户端

先安装 [Flutter SDK](https://docs.flutter.dev/get-started/install)。国内建议：

```
FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
PUB_HOSTED_URL=https://pub.flutter-io.cn
```

然后：

```bash
cd app
flutter create . --project-name taskmgr --platforms web,windows,android,ios,linux,macos
flutter pub get
flutter run -d chrome
```

Windows 桌面：

```bash
flutter run -d windows
```

Android（需 Android SDK）：

```bash
flutter run -d android
```

首次登录页填写 API 地址。Web 调试默认 `http://127.0.0.1:3000`。真机不要用 `127.0.0.1`，改成电脑的局域网 IP。

打开 App 时若当天还没看过「今日看看」，会先晃一眼前来；可跳过。标题栏太阳图标随时再看。

## API 摘要

| 方法 | 路径 | 说明 |
|---|---|---|
| POST | `/auth/register` `{email,password}` | 注册，密码至少 8 位 |
| POST | `/auth/login` | 登录 |
| POST | `/auth/refresh` `{refreshToken}` | 刷新令牌 |
| GET/PATCH | `/me` | 当前用户；PATCH `{archiveAfterDays, focusLimit, deleteArchivedAfterDays, showArchiveTab, themeKey}` |
| GET | `/tasks?status=TODO` | 列表，按优先级 |
| POST | `/tasks` | 新建，默认待办 + 中优先级 |
| PATCH | `/tasks/:id` | 改标题/正文/优先级/状态；归档任务只读 |
| DELETE | `/tasks/:id` | 待办（取消不做）或归档任务可删 |
| GET | `/briefing/today` | 今日看看 |
| POST | `/archive/run` | 立即执行归档与过期归档清理（需登录） |

除 `/auth/*` 和 `/health` 外均需 `Authorization: Bearer <accessToken>`。

## 状态流转

- 待办 ↔ 聚焦
- 聚焦 → 完成
- 完成 → 待办 / 归档
- 归档只读，不可改状态，只能删除

进入完成时写入 `completedAt`；服务端每小时把超过 `archiveAfterDays` 的完成任务改为归档（写入 `archivedAt`）。归档超过 `deleteArchivedAfterDays`（默认 30）后自动删除。聚焦同时数量受用户 `focusLimit`（默认 3）限制。
