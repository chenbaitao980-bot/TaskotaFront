# State Management

> How state is managed in this project.

---

## Overview

This project uses **flutter_bloc** for state management. The primary pattern is:

- `Bloc` (business logic component) manages state via `Event` → `State` transitions
- UI widgets use `BlocBuilder` / `BlocListener` / `BlocSelector` to react to state changes
- State is immutable — `copyWith` pattern for producing new state instances
- Database (SQLite via drift) is the source of truth; Bloc loads data on events and stores it in state

---

## State Categories

### Global State (Bloc)

| Bloc | Layer | Purpose |
|------|-------|---------|
| `TaskNewBloc` | `task_new` | Task list state: tasks, filters, view mode, projects |
| (Other blocs) | | Project, calendar, etc. |

### Local State (Widget)

- Form field values (e.g., task creation sheet)
- Animation controllers
- Search delegate query text (`SearchDelegate.query`)

### Server/Database State

- Tasks, projects, checklists are persisted in SQLite (drift)
- Bloc loads data from `TaskRepository` (which wraps drift DAOs)
- No client-side cache invalidation — always re-fetch from DB

---

## Bloc Pattern: Filter Stacking

The `TaskNewBloc` supports multiple simultaneous filters that stack together:

```
Base tasks → Project filter → Status filter → Date range filter → Search keyword filter → UI
```

### Filter Event Pattern

Each filter type follows the same pattern:

1. **Event field**: Added to `LoadTasks` event (e.g., `searchKeyword`, `statusFilter`, `projectIds`)
2. **State field**: Persisted in `TaskNewState` (e.g., `searchKeyword`, `selectedStatusFilter`, `selectedProjectIds`)
3. **Preservation on refresh**: `_onLoadTasks` and `refreshTasks` preserve existing filter values from current state
4. **Filter application**: Applied sequentially in `_onLoadTasks` (the final order matters):

```dart
// Order of filter application in _onLoadTasks:
// 1. Base: all tasks (with excluded/template project filtering)
// 2. Today/Important filter
// 3. Project filter (selectedProjectIds)
// 4. Date range filter (dateFrom, dateTo)
// 5. Status filter (selectedStatusFilter)
// 6. Search keyword filter (searchTaskIds from DB)
```

### Adding a New Filter (Checklist)

To add a new filter to `TaskNewBloc`:

1. Add field to `LoadTasks` event with `hasFieldName` boolean flag
2. Add field to `TaskNewLoaded` state
3. Add preservation logic in `_onLoadTasks` (read from current state if not explicitly set)
4. Add filter application logic after existing filters
5. Add same filter application in `refreshTasks` method
6. Update `copyWith` method to include new field

---

## Search State Management

### Events

```dart
class SetSearchQuery extends TaskEvent {
  final String? keyword; // null = clear search
  SetSearchQuery(this.keyword);
}
```

### Flow

```
SearchDelegate (UI)
  → SetSearchQuery(keyword) event
  → _onSetSearchQuery handler
  → LoadTasks(..., searchKeyword: keyword, hasSearchKeyword: true) re-emitted
  → _onLoadTasks applies all filters + DB search
  → TaskNewLoaded state emitted
  → UI rebuilds via BlocBuilder
```

### SearchDelegate Integration

- `_TaskSearchDelegate` uses `BlocBuilder<TaskNewBloc>` to render results
- 300ms debounce via `Timer` to avoid excessive DB queries
- On clear/close: emit `SetSearchQuery(null)` to reset search state
- On result tap: `close(context, taskId)` returns result to caller, caller navigates to detail

### Database Search

```dart
// TaskRepository.searchTaskIds - searches across title, description, and checklist items
Future<Set<String>> searchTaskIds(String keyword) async {
  final pattern = '%$keyword%';
  // Match tasks by title or description
  final tasksMatch = await (_db.select(_db.tasks)
    ..where((t) =>
        t.deleted.equals(0) &
        (t.title.like(pattern) | t.description.like(pattern)))
  ).get();
  final matchedIds = tasksMatch.map((t) => t.id).toSet();
  // Match by checklist item titles
  final checklistMatch = await (_db.select(_db.checklistItems)
    ..where((c) => c.deleted.equals(0) & c.title.like(pattern))
  ).get();
  matchedIds.addAll(checklistMatch.map((c) => c.taskId));
  return matchedIds;
}
```

---

## When to Use Global State

- Data shared across multiple widgets (task list, filters)
- Data that persists across navigation (selected project, filter state)
- Data requiring async loading (database queries)

---

## Permanent Global Exclusion Filter Pattern

Some fields must be **always excluded** from all normal queries — they are not user-controlled filters but hard system guards. The `archived` and `deleted` fields follow this pattern.

### Rule

**Never add permanent exclusions as BLoC-level filters.** Apply them directly in every `TaskRepository` method.

```dart
// ✅ Correct — exclusion at DB layer, always enforced
Future<List<Task>> getAll(...) async {
  final query = _db.select(_db.tasks)
    ..where((t) => t.deleted.equals(0) & t.archived.equals(0));
  ...
}

// ❌ Wrong — Bloc-level filter, easy to forget in new query paths
tasks.where((t) => t.archived == 0).toList();
```

### Checklist when adding a new permanent exclusion field

- [ ] Add `field.equals(0)` to **every** existing query method in `TaskRepository` (getAll, getRootTasks, getActiveCountForProject, getByProject, getToday, getImportant, getSubTasks, searchTaskIds)
- [ ] Verify progress calculator (`task_progress_calculator.dart`) also excludes the field
- [ ] Supabase sync push/pull both handle the field

---

## Archive View Toggle Pattern

The "archived tasks" view is a mutually exclusive mode within the task module — it's not a stacked filter. It uses a boolean flag in `TaskNewLoaded` state.

### State field

```dart
class TaskNewLoaded extends TaskNewState {
  final bool showArchivedView;  // true = show only archived; false = normal task list
  ...
}
```

### Events

```dart
class LoadArchivedTasks extends TaskNewEvent {}   // switch to archive view
class UnarchiveTask extends TaskNewEvent {         // restore single task (self only)
  final String id;
}
class ArchiveTask extends TaskNewEvent {           // archive task (recursive)
  final String id;
}
```

### Archive / Restore Behavior (Design Decision)

| Operation | Scope | Behavior |
|-----------|-------|----------|
| `ArchiveTask` | Parent + all descendants recursively | Sets `archived=1` on every descendant before archiving parent |
| `UnarchiveTask` | **Self only** | Restores only the target task; subtasks remain in their current archived state |

**Why self-only restore**: If parent is restored but children are still archived, they disappear from the parent's subtask list — which is intentional. Each archived task can be individually restored from the archive view. Bulk restore would surface tasks the user may have intentionally archived.

### Guard: block archive when subtasks incomplete

Before archiving, `ArchiveTask` handler calls `allDescendantsCompleted(id)`:

```dart
Future<bool> allDescendantsCompleted(String taskId) async {
  final children = await getSubTasksIncludingArchived(taskId);
  for (final child in children) {
    if (child.archived == 1) continue;     // already archived — skip
    if (child.status != 2) return false;   // incomplete — block
    if (!await allDescendantsCompleted(child.id)) return false;
  }
  return true;
}
```

If incomplete subtasks exist → emit `TaskNewError("子任务未完成，无法归档")` → listener shows snackbar → calls `LoadTasks()` to recover state.

---

## Common Mistakes

- **Forgetting to apply new filter in `refreshTasks`**: A filter added in `_onLoadTasks` but not in `refreshTasks` will be lost after mutations (create/update/delete).
- **Not preserving existing filter values**: When `LoadTasks` is emitted without explicit filter values, the handler should read preserved values from current state.
- **Failing to clear search on close**: The `_TaskSearchDelegate` must emit `SetSearchQuery(null)` when closing, otherwise stale search state persists.
- **Adding permanent exclusions only to `_onLoadTasks`**: Fields like `archived`/`deleted` must be filtered at the DB (Repository) level, not the BLoC level — BLoC-only filtering is bypassed by any new query path.
- **`clearCache()` missing derived fields**: Any cached flag derived from a remote query (e.g., `_isWhitelisted`) must be reset in `clearCache()`. Omitting it causes stale state to bleed into the next login session.
- **External call sites resetting archive view**: Any code path that dispatches `LoadTasks()` (e.g., `_debounceLoadTasks`, `_notifyBloc`, error recovery) must first check `showArchivedView` and dispatch `LoadArchivedTasks()` instead when the archive view is active. Otherwise the view silently resets to normal mode.

---

## Deferred Refresh Pattern (Visibility-Gated Widgets)

> **Gotcha**: A `BlocListener` that gates on a visibility flag (e.g., `_visible`) will silently discard state changes while the widget is hidden. When the widget becomes visible again, the Bloc state hasn't changed, so the listener never re-fires — the UI stays stale.

### Problem

```dart
// ❌ Wrong: state changes while _visible=false are lost forever
BlocListener<TaskNewBloc, TaskNewState>(
  listener: (context, state) {
    if (state is TaskNewLoaded && _visible) {
      _loadData(); // never called if state fired while hidden
    }
  },
)
```

When the user navigates away (tab switch, push route) and edits data in another screen, the Bloc emits a new state while this widget is hidden. On returning, no new state emission happens — the listener never triggers, and the UI shows stale data.

### Fix: Dirty Flag

```dart
// ✅ Correct: record a dirty flag when hidden, act on it when re-shown
bool _needsRefresh = false;

// BlocListener: mark instead of skip
if (state is TaskNewLoaded && !_loading && mounted) {
  if (!_visible) {
    _needsRefresh = true;
    return;
  }
  _loadData();
}

// Visibility callback: check flag on re-show
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

### When to Apply

Use this pattern whenever:
- A widget is conditionally shown/hidden (e.g., `IndexedStack` tabs, bottom nav pages)
- The widget subscribes to a Bloc that other screens can mutate
- Stale display after returning to the widget would be a visible bug

---

## Remote Dynamic Config Pattern (会员/付费配置)

### Problem

Hardcoding prices, plan limits, or feature flags ties the client to specific values. Changing prices requires a new release. This is especially dangerous for paid features (VIP plans, subscriptions).

**Wrong** — hardcoded values scattered in code:
```dart
// ❌ Hardcoded prices — requires new release to change
const vipMonthlyPriceCents = 990;  // 9.9元
const vipYearlyPriceCents = 6800;  // 68元
```

### Fix: Remote Config Service

Read VIP/member config from backend API at runtime. Fallback to safe defaults only when API is unavailable.

**Architecture**:
```
Flutter app
  → MemberConfigService (singleton, in-memory cache)
    → GET /functions/v1/member-config  (Edge Function)
      → SELECT FROM member_types  (Supabase)
    → Cache for 5 min (memory only)
```

**Service skeleton**:
```dart
class MemberConfigService {
  static final MemberConfigService instance = MemberConfigService._internal();
  factory MemberConfigService() => instance;
  
  MemberConfigService._internal();
  
  List<MemberTypeConfig> _types = [];
  DateTime? _lastFetchTime;
  
  Future<void> refresh() async {
    // Fetch from Edge Function
    // Update _types and _lastFetchTime
  }
  
  MemberTypeConfig? getMemberTypeByPlan(String plan) {
    return _types.firstWhereOrNull((t) => t.plan == plan);
  }
}
```

**UI Usage**:
```dart
// ✅ Correct: dynamic price from config service
final config = MemberConfigService.instance.getMemberTypeByPlan('vip_monthly');
final priceText = config?.priceDisplay ?? '¥9.9';
```

**Key rules**:
1. **Never hardcode** VIP prices, feature limits, or plan names in `app_constants.dart`
2. **Free tier limits** (`freeMaxProjects`, `freeMaxTasksPerProject`) are acceptable as constants — they are limits, not commercial values
3. **Edge Function must exist** — the service fails gracefully if `member-config` returns 404 (return null, UI shows error)
4. **Cache in memory only** — no SharedPreferences for config (config changes frequently enough that disk cache causes more issues than it solves)

### When to Apply

Use this pattern whenever:
- Feature pricing or limits are stored in a backend config table
- The values may change without a client release
- Multiple clients (iOS, Android, Web) need the same config values

---

## VIP Override via Whitelist Pattern (白名单豁免)

### Problem

Whitelist users have `isVip=true` (via whitelist check) but their `_cached` subscription is `free` (no real payment record). If `currentMemberConfig` uses `_cached.plan` to look up feature limits, it returns the **free plan config**, blocking VIP features like export.

```dart
// ❌ Bug: whitelist user has _cached.plan='free', config.dataExport=false
MemberTypeConfig? get currentMemberConfig {
  if (!isVip || _cached == null) return null;
  return MemberConfigService.instance.getMemberTypeByPlan(_cached!.plan.value);
  // Returns FREE config for whitelist users → all VIP features blocked
}
```

### Fix: Guard Against Mismatched isVip Source

When `isVip` is granted by whitelist (not a real paid subscription), `currentMemberConfig` must return `null` to trigger the "default allow" branch in all permission checks.

```dart
// ✅ Correct: whitelist users bypass plan-based config
MemberTypeConfig? get currentMemberConfig {
  if (!isVip) return null;
  if (_isWhitelisted && (_cached == null || !_cached!.isVip)) return null; // walk default-allow
  if (_cached == null) return null;
  return MemberConfigService.instance.getMemberTypeByPlan(_cached!.plan.value);
}

bool canExportData() {
  if (!isVip) return false;
  final config = currentMemberConfig;
  if (config == null) return true; // default allow when no config (whitelist users land here)
  return config.dataExport;
}
```

### Key Rule

> When `isVip` can be true from **multiple sources** (paid subscription OR whitelist OR future promo), `currentMemberConfig` must only look up plan config when `_cached` is the source of truth for that VIP grant. Otherwise, return `null` and let the permission methods apply their safe default.

### Independent Query for Whitelist

The whitelist check in `refresh()` runs in its own `try-catch` so it never disrupts the subscription query:

```dart
// subscription query
try {
  final response = await supabase.from('user_subscriptions')...;
  _cached = ...;
} catch (e) { ... }

// whitelist query — independent, non-blocking
try {
  final resp = await supabase.from('vip_whitelist').select('email').eq('email', email).maybeSingle();
  _isWhitelisted = resp != null;
} catch (e) {
  // silently fails; _isWhitelisted stays false
}
```
