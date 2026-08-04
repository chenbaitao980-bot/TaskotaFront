# P0 修复设计图（第四次复发轮：回滚 setOpacity + 可靠置前台 + 单实例锁）

## 改前链路（红 = 回归源）

```
便签点击 → note 通道 showMain → restoreFullWindow
  ① windowManager.show()          # 此时主窗 alpha=0（上次 hideToTray 置 0）
  ② windowManager.setOpacity(1)   # 误：把主窗变成 WS_EX_LAYERED 分层窗口
  ③ windowManager.focus()         # SetForegroundWindow 前台锁静默失败 → 不置顶
  → 主窗"不弹出"，需点任务栏；分层窗口 + 未聚焦渲染节流 → 全窗冻结

关闭主窗 → hideToTray
  setOpacity(0) → alpha=0 全透明 → windowManager.hide()
  → 下次 show 出的瞬间不可见 + 分层窗口病理（RC1）

启动（注册表自启 + 无锁）→ 双实例抢同一 smart_assistant.db（RC2）
  → WAL 锁竞争、第二实例无前台权 → 打开慢/需点任务栏
```

## 改后链路（绿 = 修复）

```
便签点击 → note 通道 showMain → restoreFullWindow
  ① windowManager.show()
  ② setAlwaysOnTop(true) → setAlwaysOnTop(false)   # HWND_TOPMOST 强制提升 z 序再解除，绕过前台锁
  ③ windowManager.focus()                          # 此时已置顶，focus 生效
  → 主窗立即弹出且在最前，无需点任务栏；非分层窗口正常合成，无冻结
  （已删 setOpacity——白屏由 home_page:997 fetchPreferences 守卫保障）

关闭主窗 → hideToTray → 仅 windowManager.hide()（已删 setOpacity(0)）

启动 → 单实例锁（single_instance.dart，回环 socket 端口 49527）
  首实例: bind 成功 → 常驻 accept，收到 taskora-show → 回 taskora-ok → 唤起主窗
  第二实例: bind 失败 → 连接发握手 → 收 ack → exit(0)（唤起首实例主窗）
  无关程序占端口: 握手无 ack → 放行本实例（避免误杀用户应用）
```

## 时序（改后）

```
进程A(首实例)                进程B(第二实例)               OS/窗口
  bind 49527 → 成功 ───────────┐
  常驻监听                    bind 失败 ─┐                │
                              连接 loopback:49527 ────────┤
                              发 taskora-show ────────────┼──▶ 进程A accept
                              收 taskora-ok ◀─────────────┼── 进程A 回 ack + 唤起主窗
                              exit(0)                     ▼ 主窗置顶弹出
```

## 文件改动

| 文件 | 改动 |
|------|------|
| `lib/core/desktop/desktop_floating_tab_controller.dart` | 删 setOpacity×2；restoreFullWindow 加 TOPMOST 切换 |
| `lib/platform/single_instance.dart`（新） | 回环 socket 单实例锁 + 握手协议 |
| `lib/main.dart` | 桌面端 `_initWindowManager` 后接入单实例锁，非主实例 exit(0) |
| `test/single_instance_test.dart`（新） | 握手协议真实 socket 测试（无关放行 / 首实例语义） |
