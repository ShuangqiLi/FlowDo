# Changelog

本项目遵循 [Semantic Versioning](https://semver.org/lang/zh-CN/) 与 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)。

版本号格式为 `MAJOR.MINOR.PATCH`（发布标签带 `v` 前缀，例如 `v0.0.1`）。`0.y.z` 表示初期，API 与界面仍可能调整。

版本号写在：

- [`VERSION`](VERSION)
- [`app/pubspec.yaml`](app/pubspec.yaml)（`version: x.y.z+build`）
- [`server/package.json`](server/package.json)

发版时同步改这三处，并在本文件新增一节。

## [Unreleased]

## [0.8.8] - 2026-10-03

### Fixed

- 底栏切页或切换任务空间时，原来选中的胶囊不再闪一下。选中底只淡出透明度，换空间带来的主题色马上换上

### Changed

- 设置关于打开时只显示当前版本和这一版的发行说明；点「检查新版」才查一次，没有新版提示已经是最新的，有新版则显示版本号并把按钮改成「更新」、发行说明改到新版本
- 退出登录改回正常的红色；外观色块直接用主题本色、字仍是浅色；新空间默认不在底栏显示归档
- 今日看看第一行日期改成「2026年10月3日 14:53」，不再显示秒；温度带 ℃；时间和天气字号放大并改用主题展示字体
- 删除任务空间前会说明当前空间里有多少件任务，并提示删除后无法找回

## [0.8.7] - 2026-10-03

### Fixed

- 任务从任务池送进聚焦时不再因为行锁 SQL 类型不对而返回 500

### Changed

- 右上角只留天气入口，今日看看里第一行左边时间、右边天气；打开后天气按钮换成叉
- 月度回顾格子左上角放日期，完成件数用圆点表示，最多 5 个
- 设置外观色块改成主题深底浅字；账户改成关于，检查更新直接在设置里；修改密码和退出登录同一层，退出登录红色更柔和

## [0.8.6] - 2026-10-03

### Fixed

- 今日看看空白处右滑可以退出；下拉刷新在列表不满一屏时也能拉动
- 加号输入框打开后，背后的任务列表仍可滑动
- 完成或改状态后，慢网刷新不再把任务刷回旧状态

## [0.8.5] - 2026-10-03

### Fixed

- 慢网下连续把任务送进聚焦时按名额排队，满了会提示，不再悄悄超出上限
- 手机键盘弹出时，加号和输入条抬到键盘上方
- 随手记里拖动选字不再被整页右滑抢走

### Changed

- 今日看看去掉「正在聚焦」，只保留「可以先做这些」（有聚焦任务时这一栏就是它们）
- 设置里的主题改成一个大色块下拉，名字写在色块上
- 右上角时间和天气同一行、字更大；天气带汉字，温度改成今日高低
- 切空间、完成任务等操作先本地更新并静默对账；访问过的空间会缓存列表，慢网也不卡庆祝动画
- 设置页改完自动保存；去掉「保存」和「现在就收拾一下」；退出登录改成红色

## [0.8.4] - 2026-10-02

### Fixed

- 离开登录或改密页后拆掉网页上的密码框，改任务状态时密码插件不再误提示更新密码

## [0.8.3] - 2026-10-02

### Fixed

- 发版检查不再被测试文件的类型提示卡住。0.8.2 的网页镜像因此失败，没有安装包

### Changed

- 客户端改为懒同步：操作先写本地，稍后再和服务器对账；任务列表、设置、今日看看都可下拉主动刷新
- 设置里当前空间的外观、聚焦、归档在前，语音和关于在后；修改密码和退出登录同一层，不再单列密码分组
- 右上角显示当前时间和天气图标，点击打开今日看看
- 空间胶囊点按时不再出现矩形选中框

## [0.8.2] - 2026-10-02

### Fixed

- 改状态、改优先级后直接用接口返回值更新列表，不再串行整表重拉
- 切空间时写回 `PATCH /me` 的结果，不再额外 `GET /me`，也不重拉空间列表
- 今日看看不再顺带拉整月回顾；月历单独请求，打开更快
- 归档和设置页左上角也是空间切换，不再显示页名

## [0.8.1] - 2026-10-02

### Fixed

- 网页里点更新时按当前容器认自己，不再拿上一次容器的短 ID 去查。已经用网页更新过的 0.7.x 会报 `No such container: <12 位 ID>`，这一次需要用启动脚本升级；之后可以继续在网页里更新

## [0.8.0] - 2026-10-02

### Breaking

- 去掉提醒事项，包括模型、`/reminders` API、农历和今日看看里的提醒入口。升级时会丢掉 `Reminder` 表

### Changed

- 主题、聚焦上限、归档天数按任务空间各自生效；`/me` 读写当前空间的设置
- 底栏纳入归档和设置，页签等宽；空白处左右滑可在全部底栏页之间循环切换
- 改密拆成独立页；关于页可打开发行说明
- 随手记输入框里选字或横滑不会退出详情，空白处右滑才关掉

### Added

- 任务详情里可换到别的任务空间，状态保持不变

### Fixed

- 新建任务后会多试几次，把新卡片滚到眼前
- 电脑上按住鼠标可以拖动底栏切页

## [0.7.3] - 2026-10-02

### Fixed

- 启动时把数据库主机名解析成 IPv4，再同步表结构。群晖等环境不会再因为先拿到一个不通的 IPv6 地址而报 `P1001: Can't reach database server at db:5432`。连不上会再试 5 次

## [0.7.2] - 2026-10-02

### Changed

- 启动时只同步当前数据库结构，不再附带一次性的数据迁移
- 文档只描述当前版本的用法

## [0.7.1] - 2026-10-02

### Fixed

- 网页里点更新不再写死 Docker API `1.44`。会先问本机引擎支持到哪个版本，老一点的 Docker（群晖常见）不会再报 `client version 1.44 is too new`
- 登录、首次改密和设置里的密码框在网页上是真正的输入框，密码填充插件可以填进来
- 密码掩码点改用半角圆点。思源黑体里的 `•` 是全角，点距会拉开近一倍

## [0.7.0] - 2026-10-01

### Breaking

- **不再支持多账号。** 一台部署只有一个登录密码。`.user` 和 `user:create` 已删除。升级时每个旧账号变成一个同名任务空间，任务跟过去；密码沿用按用户名排序后的第一个账号，其余密码作废，需要重新登录。全新安装的初始密码是 `FlowDo#321Init`（可在 `.env` 里用 `FLOWDO_INITIAL_PASSWORD` 改），第一次登录会被要求先换掉

### Added

- 任务空间：左上角菜单切换、新建、重命名、删除。任务、提醒、今日看看和归档都跟着当前空间走
- 提醒事项，和任务分开。可以一次、每天、每周、每月、每年，也可以标成纪念日。支持公历和中国农历（含闰月；某年没有这一天时落到该农历月最后一天）
- 今日看看的日历可以左右滑动查看其他月份，格子上标注农历
- 设置里可以修改密码，密码只以 bcrypt 存在数据库

### Changed

- 底栏改成悬浮胶囊，任务池 / 聚焦 / 完成三等分，选中项用浅色药丸包住图标和文字
- 底栏跨页切换不再滑过中间那一页
- 网页上用鼠标拖选输入框里的文字时，不再把整页拖走
- 新建任务后，任务池会滚到这条新任务
- 开屏只保留网页自带的那一段，不再在 Flutter 里重画一遍再硬切；登录、改密、首页之间淡入淡出

## [0.6.1] - 2026-09-27

### Fixed

- 启动脚本先起数据库和接口，再单独起网页，失败会再试一次。群晖上接口挂了 Docker 套接字之后，同一次 `up` 里接着起网页会被引擎掐断（`/start: EOF`），网页容器停在 Starting

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

[Unreleased]: https://github.com/ShuangqiLi/FlowDo/compare/v0.8.8...HEAD
[0.8.8]: https://github.com/ShuangqiLi/FlowDo/compare/v0.8.7...v0.8.8
[0.8.7]: https://github.com/ShuangqiLi/FlowDo/compare/v0.8.6...v0.8.7
[0.8.6]: https://github.com/ShuangqiLi/FlowDo/compare/v0.8.5...v0.8.6
[0.8.5]: https://github.com/ShuangqiLi/FlowDo/compare/v0.8.4...v0.8.5
[0.8.4]: https://github.com/ShuangqiLi/FlowDo/compare/v0.8.3...v0.8.4
[0.8.3]: https://github.com/ShuangqiLi/FlowDo/compare/v0.8.2...v0.8.3
[0.8.2]: https://github.com/ShuangqiLi/FlowDo/compare/v0.8.1...v0.8.2
[0.8.1]: https://github.com/ShuangqiLi/FlowDo/compare/v0.8.0...v0.8.1
[0.8.0]: https://github.com/ShuangqiLi/FlowDo/compare/v0.7.3...v0.8.0
[0.7.3]: https://github.com/ShuangqiLi/FlowDo/compare/v0.7.2...v0.7.3
[0.7.2]: https://github.com/ShuangqiLi/FlowDo/compare/v0.7.1...v0.7.2
[0.7.1]: https://github.com/ShuangqiLi/FlowDo/compare/v0.7.0...v0.7.1
[0.7.0]: https://github.com/ShuangqiLi/FlowDo/compare/v0.6.1...v0.7.0
[0.6.1]: https://github.com/ShuangqiLi/FlowDo/compare/v0.6.0...v0.6.1
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
