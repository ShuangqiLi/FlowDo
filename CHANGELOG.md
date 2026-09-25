# Changelog

本项目遵循 [Semantic Versioning](https://semver.org/lang/zh-CN/) 与 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)。

版本号格式为 `MAJOR.MINOR.PATCH`（发布标签带 `v` 前缀，例如 `v0.0.1`）。`0.y.z` 表示初期，API 与界面仍可能调整。

版本号写在：

- [`VERSION`](VERSION)
- [`app/pubspec.yaml`](app/pubspec.yaml)（`version: x.y.z+build`）
- [`server/package.json`](server/package.json)

发版时同步改这三处，并在本文件新增一节。

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

[0.0.2]: https://github.com/ShuangqiLi/FlowDo/compare/v0.0.1...v0.0.2
[0.0.1]: https://github.com/ShuangqiLi/FlowDo/releases/tag/v0.0.1
