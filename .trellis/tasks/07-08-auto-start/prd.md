# brainstorm: 桌面端开机自动启动功能

## Goal

给 Windows 桌面端（Taskora）添加开机自动启动功能，用户在设置页可以开关。

## What I already know

- 这是一个 Flutter Windows 桌面应用（单实例，已用 Mutex 防止多开）
- 已安装 `window_manager: ^0.5.1` — 自带 `setAsStartupItem(bool)` 和 `isStartupItem()` API，用于管理开机启动注册表项
- 已安装 `win32_registry`（作为 transitive 依赖）— 备选方案
- 设置页在 `lib/presentation/pages/profile/app_settings_page.dart`，使用 `LocalStorageService`（基于 SharedPreferences）存偏好
- `LocalStorageService` 在 `lib/services/local_storage_service.dart`
- 桌面端平台桥接在 `lib/platform/window_manager_bridge_desktop.dart`
- `window_manager` 原生实现就是读写 Windows 注册表 `HKCU\Software\Microsoft\Windows\CurrentVersion\Run`

## Assumptions (temporary)

- 仅支持 Windows 桌面端（macOS/Linux 暂不做），但代码保持平台无关接口
- 默认关闭（用户手动开启）
- 开机启动只启动到系统托盘（保持最小化），不弹出主窗口

## Open Questions

1. MVP scope — 仅开关 + 持久化，还是需要更多（如开机启动时保持托盘模式不弹窗）？
2. 状态同步策略 — 开启/关闭后是否需要在下次启动时验证注册表状态？

## Requirements (evolving)

- [ ] 设置页增加"开机自动启动"开关
- [ ] 开关调用 `windowManager.setAsStartupItem(bool)` 控制注册表
- [ ] 设置值持久化到 SharedPreferences
- [ ] 仅在 Windows 桌面端显示此选项

## Acceptance Criteria (evolving)

- [ ] 开启后重启 Windows，Taskora 自动启动
- [ ] 关闭后重启 Windows，Taskora 不再自启
- [ ] 开关状态在重启 App 后保持
- [ ] 非 Windows 平台不显示此选项

## Technical Approach (proposed)

**方案：直接使用 `window_manager` 的 `setAsStartupItem()` API**

- 在 `LocalStorageService` 新增 `desktopAutoStart` key
- 在 `AppSettingsPage` 的桌面设置区加 SwitchListTile
- 开关触发 → `windowManager.setAsStartupItem(value)` + 存偏好
- 初始化时读偏好同步 UI 状态
- 不需要写原生代码、不需要加新依赖

## Out of Scope

- macOS/Linux 开机启动
- 开机启动后自动最小化到托盘（已有「关闭后显示页签」控制）
- 启动延迟策略

## Technical Notes

- `window_manager` 0.5.1 在 Windows 上通过注册表 `HKCU\...\Run` 实现，不需要管理员权限
- 已有的 `ensureWindowManagerInitialized()` 在桌面端启动时已调用，可直接使用 `windowManager`

## Spec Conflicts

- （无）
