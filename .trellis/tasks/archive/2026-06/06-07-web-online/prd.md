# web-online: 开发 Taskora Web 在线版本

## Goal

让 Taskora AI 日程管家能以网页形式在浏览器中访问，使用户无需安装 App 即可在电脑/手机浏览器中使用核心功能。

## What I already know

* 项目已是 Flutter 跨平台项目，已有 `web/` 目录（默认脚手架，未深度定制）
* `flutter build web` 命令可用（Flutter Web 支持已就位）
* 存在多个不兼容 Web 的依赖：
  - `sqlite3_flutter_libs` — 原生 SQLite 绑定，Web 不支持
  - `system_tray` — 桌面托盘，Web 无对应
  - `flutter_local_notifications_windows` — Windows 专属
  - `aliyun_push` — 移动推送，Web 不支持
  - `alarm` — 闹钟包，Web 支持有限
  - `flutter_local_notifications` — Web 支持有限
* Supabase 已集成（数据云端同步），可在 Web 端直接使用
* `speech_to_text` 有浏览器 Web Speech API 支持

## Assumptions (temporary)

* 使用 Flutter Web 方案（复用现有 Dart 代码，而非重写为 React/Vue）
* Web 版本不需要原生功能（托盘、本地通知、推送、本地 SQLite）
* Supabase 作为 Web 端唯一数据源（不使用本地 DB）

## Open Questions

* 核心问题：Web 版定位是"完整功能镜像"还是"核心功能子集"？
* 平台检测：需要条件编译分离平台代码吗？
* 部署目标：部署在哪里（Vercel/Firebase Hosting/自有服务器）？

## Requirements (evolving)

* [ ] Flutter Web 可成功构建
* [ ] 处理不兼容依赖（平台检测 + stub/替换）
* [ ] 核心任务管理功能可在浏览器中运行
* [ ] Supabase 数据同步正常工作

## Acceptance Criteria (evolving)

* [ ] `flutter build web` 无报错
* [ ] 浏览器中能登录、查看任务列表、创建任务
* [ ] 不兼容功能（推送/托盘）在 Web 上优雅降级或隐藏

## Definition of Done

* Flutter Web build 成功，无编译错误
* 核心功能在 Chrome/Edge 中手工验证通过
* 不兼容依赖已通过平台 stub 或条件编译处理

## Out of Scope (TBD)

* (待确认)

## Technical Notes

* 不兼容依赖需用 `kIsWeb` 或 `dart:io` 条件处理
* `sqlite3_flutter_libs` 可能需要用 `drift` 的 Web 实现（IndexedDB）替代，或直接 Web 端走 Supabase 纯远程
* `system_tray` / `aliyun_push` 需要 stub 实现（空实现）
