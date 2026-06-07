# 修复首页切回时逾期/时间轴不刷新

## Goal

在思维导图（或其他后台 tab）修改任务时间后，切换回首页，时间轴和逾期区域应立即显示最新状态。当前行为：首页数据停留在旧状态，需要手动下拉刷新才能更新。

## Requirements

- 当用户切换回首页 tab 时，若后台期间发生过任务数据变化（TaskNewLoaded 事件），首页应自动刷新数据
- 若后台期间没有发生变化，不触发额外的数据库查询（性能优化）
- 覆盖所有"后台修改后切回首页"的场景：思维导图改时间、任务详情改属性、任何 tab 内修改等

## Acceptance Criteria

- [ ] 在思维导图修改任务时间（使其从逾期变为未来），切换回首页，逾期数量立即更新
- [ ] 在思维导图修改任务时间，切换回首页，时间轴位置立即反映新时间
- [ ] 用户频繁切换 tab（无数据变化）不会触发额外的数据库查询
- [ ] 现有手动下拉刷新功能不受影响

## Definition of Done

- 代码改动通过 lint / type-check
- 逻辑自洽，无副作用

## Technical Approach

**根因**：`_onVisibleTabChanged()` 切回首页时只做 `setState()` 触发 rebuild，没有调用 `_loadData()`。而 `BlocListener` 在首页不可见（`_visible = false`）时收到 `TaskNewLoaded` 直接 return，导致数据变化被丢弃。

**方案：脏标记法**

1. 新增字段 `bool _needsRefresh = false`
2. `BlocListener` 在 `_visible == false` 时不再直接 return，而是设 `_needsRefresh = true`
3. `_onVisibleTabChanged()` 切回首页时，若 `_needsRefresh == true` 则调用 `_loadData()` 并清零标记

**改动文件**：`lib/presentation/pages/home/home_page.dart`

**改动点**：

```dart
// ① 新增字段（状态变量区）
bool _needsRefresh = false;

// ② BlocListener（去掉 _visible 门控，改为后台记标记）
if (state is TaskNewLoaded && !_loading && mounted) {
  if (!_visible) {
    _needsRefresh = true;
    return;
  }
  final now = DateTime.now();
  if (_lastLoadTime != null &&
      now.difference(_lastLoadTime!) < const Duration(seconds: 2)) {
    return;
  }
  _lastLoadTime = now;
  _loadData();
}

// ③ _onVisibleTabChanged（切回时检查标记）
void _onVisibleTabChanged() {
  if (!mounted) return;
  final nowVisible = widget.visibleTabIndex.value == 0;
  if (_visible == nowVisible) return;
  setState(() => _visible = nowVisible);
  if (nowVisible && _needsRefresh) {
    _needsRefresh = false;
    _loadData();
  }
}
```

## Out of Scope

- 其他 tab（任务页、日历页）的刷新逻辑
- 首页以外的逾期提醒通知

## Technical Notes

- 关键文件：`lib/presentation/pages/home/home_page.dart`
- BlocListener 位置：line ~1248
- `_onVisibleTabChanged` 位置：line ~742
- `_lastLoadTime` 节流只针对 BlocListener，`_loadData()` 本身无节流（仅 `_loading` 锁）
