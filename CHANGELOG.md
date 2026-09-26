# Changelog

本项目遵循 [Semantic Versioning](https://semver.org/lang/zh-CN/) 与 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)。

版本号格式为 `MAJOR.MINOR.PATCH`（发布标签带 `v` 前缀，例如 `v0.0.1`）。`0.y.z` 表示初期，API 与界面仍可能调整。

版本号写在：

- [`VERSION`](VERSION)
- [`app/pubspec.yaml`](app/pubspec.yaml)（`version: x.y.z+build`）
- [`server/package.json`](server/package.json)

发版时同步改这三处，并在本文件新增一节。

## [Unreleased]

## [0.6.0] - 2026-09-27

### Added

- 设置里新增「关于」：显示当前版本，联网能查到更新时可以在网页里一键换上新版本。数据库不动；部署目录没把 Docker 交给服务端时，会提示改用启动脚本

## [0.5.0] - 2026-09-27

### Added

- 部署目录的 `.user` 是账号的唯一来源。`start.sh` / `start.ps1` 在服务就绪后按它同步：没有的新建，密码不同的更新，文件里没有的从数据库删除（任务一并删除）。文件不存在时不改动数据库

### Fixed

- 数据库卷名固定为 `flowdo_data`。之前 Compose 项目名再加一次前缀，实际卷名是 `flowdo_flowdo_data`。启动脚本会把旧卷拷到新名字，旧卷先留着

## [0.4.0] - 2026-09-26

### Added

- 设置里新增「语音输入」开关，跟随账号；打开时进入首页就申请一次麦克风，之后长按加号不用再确认
- 设置里显示浏览器当前给不给麦克风（已允许 / 被拒绝 / 还没问过 / http 地址不开放 / 浏览器不支持），
  还没问过时可以直接点按钮申请
- 部署包里每个镜像旁多了 `*.id`，启动脚本会跳过本机已有的镜像
- `DEPLOY.md`：部署、升级、语音输入、停止与数据的完整说明，发版包里的 `README.md` 就是它

### Changed

- **登录改用用户名**，不再要求邮箱格式；`npm run user:create -- user 'password'` 只要用户名和密码，
  不再限制密码长度。老账号用原来的邮箱当用户名照常登录，数据库结构不变
- 发版包改名 `FlowDo-vX.Y.Z.zip`，里面只有 `docker-compose.yml`、两个镜像（带 `.id`）、
  `start.sh` / `start.ps1` 和 `README.md`，不再塞 `web-build/`
- `scripts/deploy.*` 和 `release/docker/start.*` 合并成仓库根目录的 `start.sh` / `start.ps1`：
  旁边有镜像包就加载镜像，是源码目录就先构建镜像；启动后等 API 和网页端都通过健康检查，
  没起来就打印容器状态和日志并以非零退出
- 底栏改成平铺：任务池 / 聚焦 / 完成三等分，不再是半椭圆台面；聚焦坐中间，一颗更大的圆按钮，
  选中时整颗填色；两侧页签选中时只在图标背后亮一枚胶囊，文字不再被框起来
- 服务端镜像只带运行时依赖，并去掉 Prisma 重复的查询引擎和其他数据库的 wasm 引擎，
  压缩后从 187MB 减到约 99MB；容器启动直接用 node 跑 Prisma CLI，不再经过 npx，也不联网查版本
- 网页端镜像分阶段整理产物：删掉 dart2js 构建用不到的 skwasm / wimp 等 wasm 渲染器和调试符号，
  `assets/`、`canvaskit/` 只保留预压的 `.gz`（nginx `gzip_static always` + `gunzip`），
  压缩后从 73MB 减到约 40MB
- 发版流水线拆成服务端镜像、网页端镜像两个并行 job，Docker 层用 GitHub Actions 缓存，
  镜像用 pigz 多线程压缩，zip 里不再二次压缩 tar.gz
- 数据库健康检查 2 秒一次，API 容器自带健康检查

### Fixed

- 语音输入失败时不再只显示 `not-allowed` 这种错误码：区分 http 地址不开放麦克风、用户拒绝、
  没有麦克风、识别服务连不上、浏览器不支持等情况，并写明怎么解决；出错后输入框自动切成打字
- 网页端 `assets/`、`canvaskit/` 不再让浏览器缓存一周：升级后图标字体是新裁剪的，老缓存会让部分图标不显示

### Removed

- `scripts/` 与 `release/` 目录，功能并入根目录 `start.sh` / `start.ps1` 和 `DEPLOY.md`

## [0.3.0] - 2026-09-26

### Removed

- **客户端只保留网页端**：不再发布和维护 Android、iOS、Windows 客户端，
  仓库里的 `app/android`、`app/windows` 平台目录一并删除
- 删除 Caddy、HTTPS profile、公网部署脚本和相关配置；项目只考虑可信内网 HTTP
- 删除网页端注册入口、API 地址输入和设置；服务端不再暴露 `POST /auth/register`
- 发版产物精简为唯一的 `FlowDo-docker-*.zip`

### Added

- 网页端有了自己的容器：`web/Dockerfile` + nginx 配置，`docker compose up -d`
  一起拉起，默认开在 `8080`
- nginx 把 API 路径同源反代给服务端，手机和电脑访问 `http://主机:8080` 即可
- 新增部署机账号创建命令：`docker compose exec api npm run user:create -- 邮箱 密码`
- 唯一部署包同时包含服务端/网页端镜像、Compose、启动脚本和完整 `web-build/`

### Fixed

- 网页端图标和中文变成方块乱码：产物必须整目录部署，少了 `assets/` 或 `canvaskit/`
  就没有字体和图标。现在由镜像托管，nginx 对缺失的资源直接返回 404 而不是拿首页顶包，
  构建时也会检查关键文件
- 网页端改用打进镜像的 CanvasKit（`--no-web-resources-cdn`），不再依赖 `gstatic.com`
- 本地 Windows 调试时长按加号不再因语音插件闪退
- 底栏半椭圆台面恢复显示（弧线画反了，之前整个台面都没画出来）
- 底栏「聚焦」等方块不再探出台面盖住上面的任务列表和今日看看

### Changed

- Web 和 API 端口分别通过 `WEB_PORT` / `API_PORT` 配置；数据库只在 Compose 网络内访问

## [0.2.2] - 2026-09-25

### Added

- 冷启动开屏：品牌图形标和「随随办办」

### Changed

- 完成庆祝动画稍慢一点，粒子略增

## [0.2.1] - 2026-09-25

### Changed

- 减轻左右滑切页与任务卡拖动时的卡顿（去掉底栏 3D 透视、列表入场动画，滑动时少重建）
- 完成庆祝动画更轻：去掉模糊光晕、粒子减半、时长缩短

## [0.2.0] - 2026-09-25

### Added

- 可拖动贴边的加号：点按写任务、长按语音；加完跳到任务池
- 今日看看的月度回顾日历，点一天能看见当天搞定的事

### Changed

- 底栏只留任务池 / 聚焦 / 完成，左右滑也能切页；归档改到左上角（设置里可关掉）
- 设置、归档、详情可以右滑返回
- 电脑和网页也改成和手机一样的左右滑，不再用按钮
- 从聚焦或完成放回任务池后留在当前页，不再自动跳走
- 四套主题改名为闲云 / 远山 / 归途 / 微光，配色更淡；任务卡按优先级铺浅渐变

## [0.1.0] - 2026-09-25

### Changed

- 桌面和网页用按钮操作任务，手机和平板改用左右滑、不再放按钮
- 主界面不再在左上角重复底栏已经写明的页面名
- 随手记只保留标题和记录；桌面和网页的任务池增加「不做了」
- 新任务默认使用中优先级，新增区简化为文字或语音输入
- 语音输入改成按住麦克风说话、松开结束；提交后迟到的识别结果不再写回输入框
- 语音识别结果去掉末尾的句号、问号等标点
- 所有界面都不再显示水平和垂直滚动条，内容放不下时可以直接拖动，鼠标也能拖
- 「归档后几天自动清掉」填 0 表示永久保留，不会自动删除
- 优先级改为贴着图标弹出的小菜单，不再用占满屏幕的对话框
- 任务池显示加入日期，完成和归档分别显示搞定、归档日期
- 工程内旧名 taskMgr / taskmgr 全部改为 FlowDo / flowdo，开发库账号与库名同步为 flowdo
- 发版服务端公网只开放 80/443（Caddy HTTPS），API 不再映射到 0.0.0.0:3000
- Caddyfile 与 docker-compose.yml 只在仓库根目录维护一份，发版包从这里拷贝

### Fixed

- 滑走今日看看后按钮卡在关闭态、面板却打不开
- 「可以先做这些」优先列出聚焦任务，没有才从任务池推荐几件高优先级

## [0.0.4] - 2026-09-25

### Changed

- 优先级改回用「高 / 中 / 低」文字显示，不再用箭头图标

### Fixed

- 滑动任务时立刻移走卡片，避免 Slidable 报错
- 外观主题切换失败时给出提示，不再静默吞掉错误
- 登录和注册的密码掩码点过宽（思源黑体里的 • 是全角字形）

## [0.0.3] - 2026-09-25

### Added

- 薄荷绿、雾霾蓝、暖橘色、淡紫色四套账号同步主题
- FlowDo UI Kit、跨平台中文字体、对勾图形标与任务完成庆祝动画
- GitHub Release 增加 iOS IPA（默认未签名，见下方说明）

### Changed

- 以低饱和配色、留白卡片、圆角图标和轻量转场重设计全部客户端页面

## [0.0.2] - 2026-09-25

### Added

- GitHub Release 分别提供可直接使用的服务端 Docker 包、Windows 客户端、
  Android APK 和 Web 客户端

### Fixed

- 兼容 Flutter 新版依赖中的 Riverpod 3 API
- GitHub Actions 在 tag checkout 下无法创建 Release

## [0.0.1] - 2026-09-25

### Added

- 随随办办 / FlowDo 首个可用版本：任务池 → 聚焦 → 完成 → 归档
- NestJS + PostgreSQL 服务端，JWT 多用户隔离
- Flutter 客户端（Web / 桌面 / 移动），今日看看、优先级、归档自动清理
- Docker 本机启动与带域名的公网 HTTPS（辅助脚本在 `scripts/`）
- 通过 GitHub Releases 发版（推送 `v*.*.*` 标签）
- 账号级设置（聚焦上限、归档天数、是否显示归档页）

[Unreleased]: https://github.com/ShuangqiLi/FlowDo/compare/v0.6.0...HEAD
[0.6.0]: https://github.com/ShuangqiLi/FlowDo/compare/v0.5.0...v0.6.0
[0.5.0]: https://github.com/ShuangqiLi/FlowDo/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/ShuangqiLi/FlowDo/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/ShuangqiLi/FlowDo/compare/v0.2.2...v0.3.0
[0.2.2]: https://github.com/ShuangqiLi/FlowDo/compare/v0.2.1...v0.2.2
[0.2.1]: https://github.com/ShuangqiLi/FlowDo/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/ShuangqiLi/FlowDo/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/ShuangqiLi/FlowDo/compare/v0.0.4...v0.1.0
[0.0.4]: https://github.com/ShuangqiLi/FlowDo/compare/v0.0.3...v0.0.4
[0.0.3]: https://github.com/ShuangqiLi/FlowDo/compare/v0.0.2...v0.0.3
[0.0.2]: https://github.com/ShuangqiLi/FlowDo/compare/v0.0.1...v0.0.2
[0.0.1]: https://github.com/ShuangqiLi/FlowDo/releases/tag/v0.0.1
