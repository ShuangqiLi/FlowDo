# Changelog

本项目遵循 [Semantic Versioning](https://semver.org/lang/zh-CN/) 与 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)。

版本号格式为 `MAJOR.MINOR.PATCH`（发布标签带 `v` 前缀，例如 `v0.0.1`）。`0.y.z` 表示初期，API 与界面仍可能调整。

版本号写在：

- [`VERSION`](VERSION)
- [`app/pubspec.yaml`](app/pubspec.yaml)（`version: x.y.z+build`）
- [`server/package.json`](server/package.json)

发版时同步改这三处，并在本文件新增一节。

## [Unreleased]

### Fixed

- 滑动任务时立刻移走卡片，避免 Slidable 报错
- 外观主题切换失败时给出提示，不再静默吞掉错误

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

[Unreleased]: https://github.com/ShuangqiLi/FlowDo/compare/v0.0.3...HEAD
[0.0.3]: https://github.com/ShuangqiLi/FlowDo/compare/v0.0.2...v0.0.3
[0.0.2]: https://github.com/ShuangqiLi/FlowDo/compare/v0.0.1...v0.0.2
[0.0.1]: https://github.com/ShuangqiLi/FlowDo/releases/tag/v0.0.1
