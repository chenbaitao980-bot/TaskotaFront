# fix: ctrl+scroll zoom 无法以滚动中心缩放

## Goal

桌面端 Ctrl+滚轮缩放时，应以鼠标光标所在位置为锚点放大缩小（zoom-to-cursor），但实际缩放的锚点一直是视口中心，与预期不符。

## Root Cause

三处 Bug，主因是重建链路断裂：

**Bug 0 — `_setHourHeight:397`（真正根因，回归）**
性能优化提交 `c62144c` 把 `setState(() => _hourHeight = nextHeight)` 改成
`_hourHeightNotifier.value = nextHeight`，注释声称"只重建周视图网格 VLB 子树"，
但全文件**没有任何 ValueListenableBuilder 监听 `_hourHeightNotifier`**
（两处 VLB 监听的都是 `_dragOffset`）。结果高度值变了 UI 不重建，
Ctrl+滚轮 / 双指 / 工具栏按钮的缩放全部视觉失效。

**Bug 1 — `_handleTimelinePointerSignal:426`**
调用 `_setHourHeight` 时未传 `focalPointOffset`，缩放回退到视口中心锚点。

**Bug 2 — `_setHourHeight` postFrameCallback:406**
焦点锚点下的滚动偏移公式缺少减法：
- 错误：`newFocalOffset = anchorHour * newHourHeight`（焦点被移到视口顶部）
- 正确：`newFocalOffset = anchorHour * newHourHeight - capturedFocal`

## Fix Applied

0. **接回局部重建**（修 Bug 0）：保留 `_hourHeightNotifier.value = nextHeight`，
   并在网格子树外补上监听它的 `ValueListenableBuilder<double>`（嵌套在拖拽 VLB 外层），
   `totalHeight` 移入该 builder。缩放只重建网格子树，不整页重建 → 消除闪烁。
   拖拽时外层不触发，仍走内层 VLB 只重建 Transform（保留 H1 优化）。
1. `_handleTimelinePointerSignal`: 传入 `focalPointOffset: event.localPosition.dy`
2. `_setHourHeight` postFrameCallback: `newFocalOffset = capturedAnchor * _hourHeight - capturedFocal`

## 演进记录

- 首轮误判为锚点问题，仅改 1/2 → 用户反馈"完全没缩放效果"
- 二轮定位真根因 Bug 0（notifier 无监听），先用 setState 整页重建修复 → 用户反馈"闪烁不流畅"
- 三轮接回作者本意的局部重建 VLB，既流畅又正确
- 四轮（Bug 3）：缩放可用后发现 Ctrl+滚轮仍上下滚动 —— 缩放 `Listener` 在
  `SingleChildScrollView` 外层，viewport 先 `register` 赢得 `pointerSignalResolver`，
  缩放回调被静默丢弃。把缩放 `Listener` 移入 ScrollView 内层（先注册赢），滚动被拦截。
  详见 frontend/component-guidelines.md「PointerSignal 与 ScrollView 共存」。

## Bug 3 — pointerSignalResolver 注册顺序（Ctrl+滚轮仍滚动）

**根因**：`PointerSignalResolver` 只执行第一个 `register` 的回调，注册顺序沿命中路径从内到外。
缩放 `Listener` 在 viewport 外层 → viewport 先注册赢 → 缩放回调被忽略 → 继续滚动。

**修复**：
1. 把 `onPointerSignal: _handleTimelinePointerSignal` 从外层 `Listener` 移到
   `SingleChildScrollView` 内部、包住 `SizedBox` 内容的新 `Listener`
   （`behavior: HitTestBehavior.translucent`），先注册赢得 resolver。
2. 外层 `Listener` 只保留 pinch 用的 `onPointerDown/Move/Up`。
3. 坐标系修正：内层 `Listener` 的 `localPosition.dy` 变为内容坐标（含滚动），
   回调内 `focal = localPosition.dy - scrollOffset` 转回视觉坐标，焦点不漂移。

## Out of Scope

- pinch zoom 公式中 `focalPointOffset` 多余的 `+ scrollOffset`（未报告，留待后续）

## Technical Notes

- 文件：`lib/presentation/pages/calendar/calendar_page.dart`
- `_setHourHeight` 公式 `(position.pixels + focalPointOffset) / hourHeight` 期望的是**视觉 Y**（相对视口顶部、不含 scroll）
- Bug 3 修复**前**：缩放 `Listener` 在 ScrollView 外层，`event.localPosition.dy` 即视觉 Y，可直接传入
- Bug 3 修复**后**：缩放 `Listener` 移入 ScrollView 内层，`event.localPosition.dy` 变为内容 Y（含 scroll），
  须 `localPosition.dy - scrollOffset` 转回视觉 Y 再传入
