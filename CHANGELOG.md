# Changelog

本项目遵循 [Semantic Versioning](https://semver.org/lang/zh-CN/) 与 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)。

版本号格式为 `MAJOR.MINOR.PATCH`（发布标签带 `v` 前缀，例如 `v0.0.1`）。`0.y.z` 表示初期，API 与界面仍可能调整。

版本号写在：

- [`VERSION`](VERSION)
- [`app/pubspec.yaml`](app/pubspec.yaml)（`version: x.y.z+build`）
- [`server/package.json`](server/package.json)

发版时同步改这三处，并在本文件新增一节。

## [Unreleased]

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

[Unreleased]: https://github.com/ShuangqiLi/FlowDo/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/ShuangqiLi/FlowDo/compare/v0.0.4...v0.1.0
[0.0.4]: https://github.com/ShuangqiLi/FlowDo/compare/v0.0.3...v0.0.4
[0.0.3]: https://github.com/ShuangqiLi/FlowDo/compare/v0.0.2...v0.0.3
[0.0.2]: https://github.com/ShuangqiLi/FlowDo/compare/v0.0.1...v0.0.2
[0.0.1]: https://github.com/ShuangqiLi/FlowDo/releases/tag/v0.0.1
