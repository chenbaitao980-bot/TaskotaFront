import 'dart:convert';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/utils/file_logger.dart';
import '../../core/utils/platform_utils.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/task_repository.dart';
import '../../services/local_storage_service.dart';
import 'window_state.dart';

class DesktopFloatingTaskSummary {
  final String taskId;
  final String title;
  final int priority;
  final DateTime anchorDate;
  final DateTime? dueDate;
  final int extraTaskCount;

  const DesktopFloatingTaskSummary({
    required this.taskId,
    required this.title,
    required this.priority,
    required this.anchorDate,
    required this.dueDate,
    required this.extraTaskCount,
  });

  /// 序列化为跨引擎通道载荷（便签窗不读 SQLite，摘要由主窗计算后推送）。
  Map<String, dynamic> toJson() => {
        'taskId': taskId,
        'title': title,
        'priority': priority,
        'anchorDate': anchorDate.toIso8601String(),
        'dueDate': dueDate?.toIso8601String(),
        'extraTaskCount': extraTaskCount,
      };

  factory DesktopFloatingTaskSummary.fromJson(Map<String, dynamic> json) {
    return DesktopFloatingTaskSummary(
      taskId: json['taskId'] as String,
      title: json['title'] as String,
      priority: json['priority'] as int,
      anchorDate: DateTime.parse(json['anchorDate'] as String),
      dueDate: json['dueDate'] == null
          ? null
          : DateTime.parse(json['dueDate'] as String),
      extraTaskCount: json['extraTaskCount'] as int,
    );
  }
}

/// 主窗 → 便签窗通道：便签窗注册 handler，主窗 invoke（推送摘要 / 隐藏）。
const WindowMethodChannel _noteUpdateChannel = WindowMethodChannel(
  'taskora_note_update',
  mode: ChannelMode.unidirectional,
);

/// 便签窗 → 主窗通道：主窗注册 handler，便签窗 invoke（唤起 / 关闭）。
const WindowMethodChannel _noteCommandChannel = WindowMethodChannel(
  'taskora_note_command',
  mode: ChannelMode.unidirectional,
);

class DesktopFloatingTabController extends ChangeNotifier {
  DesktopFloatingTabController._();

  static final DesktopFloatingTabController instance =
      DesktopFloatingTabController._();

  final LocalStorageService _storage = LocalStorageService();

  TaskRepository? _taskRepository;
  WindowController? _noteWindow;
  bool _storageReady = false;
  bool _defaultEnabled = true;
  bool _dismissedUntilRestore = false;
  bool _isTransitioning = false;
  bool _canShowFloatingTab = false;
  bool _mainChannelRegistered = false;

  /// 便签点击待定位任务：一次性消费，由首页 _loadData postFrame 读取后清空。
  String? pendingFocusTaskId;
  int? pendingFocusRequestToken;

  bool get defaultEnabled => _defaultEnabled;

  void bindTaskRepository(TaskRepository? repository) {
    _taskRepository = repository;
  }

  void setCanShowFloatingTab(bool value) {
    if (_canShowFloatingTab == value) return;
    _canShowFloatingTab = value;
  }

  Future<void> ensureInitialized() async {
    if (_storageReady) return;
    await _storage.init();
    _defaultEnabled = _storage.desktopFloatingTabEnabled;
    _storageReady = true;
  }

  Future<void> refreshSettings() async {
    await ensureInitialized();
    _defaultEnabled = _storage.desktopFloatingTabEnabled;
    notifyListeners();
  }

  /// 关闭主窗：命中候选则创建/复用便签窗并隐藏主窗；否则仅隐藏。
  Future<void> handleCloseRequested() async {
    if (!isWindows || _isTransitioning) {
      flog(
        '[FloatingTab] handleCloseRequested: 非Windows或转换中 -> hideToTray '
        '(isWindows=$isWindows, transitioning=$_isTransitioning)',
      );
      await hideToTray();
      return;
    }
    await ensureInitialized();

    if (!_canShowFloatingTab || !_defaultEnabled || _dismissedUntilRestore) {
      flog(
        '[FloatingTab] handleCloseRequested: 闸门未通过 -> hideToTray '
        '(canShow=$_canShowFloatingTab, enabled=$_defaultEnabled, '
        'dismissed=$_dismissedUntilRestore)',
      );
      await hideToTray();
      return;
    }

    final candidate = await _selectTaskForFloatingTab();
    if (candidate == null) {
      flog('[FloatingTab] handleCloseRequested: 无未完成任务候选 -> hideToTray');
      await hideToTray();
      return;
    }

    flog(
      '[FloatingTab] handleCloseRequested: 命中候选 taskId=${candidate.taskId} '
      'title="${candidate.title}" extra=${candidate.extraTaskCount} -> 显示便签窗并隐藏主窗',
    );

    _isTransitioning = true;
    try {
      await _showNoteWindow(candidate);
      await hideToTray();
    } finally {
      _isTransitioning = false;
    }
  }

  /// 恢复主窗：隐藏便签窗，show+focus 主窗。openTaskId 时写入待定位字段。
  Future<void> restoreFullWindow({String? openTaskId}) async {
    if (!isWindows || _isTransitioning) return;
    if (openTaskId != null && openTaskId.isNotEmpty) {
      pendingFocusTaskId = openTaskId;
      pendingFocusRequestToken = DateTime.now().microsecondsSinceEpoch;
    }
    _dismissedUntilRestore = false;
    await _hideNoteWindow();

    await windowManager.show();
    await windowManager.focus();
    desktopWindowVisible = true;
  }

  /// 便签"关闭"：置 dismissed，隐藏便签窗；主窗保持隐藏（下次关闭不弹便签）。
  Future<void> closeFloatingTab() async {
    _dismissedUntilRestore = true;
    await _hideNoteWindow();
  }

  Future<void> hideToTray() async {
    desktopWindowVisible = false;
    await windowManager.hide();
  }

  /// 确保便签窗存在（懒建一次，后续复用规避 #484 句柄泄漏）。
  Future<void> _ensureNoteWindow(DesktopFloatingTaskSummary summary) async {
    if (_noteWindow != null) return;
    await _registerMainWindowChannel();
    try {
      _noteWindow = await WindowController.create(
        WindowConfiguration(
          hiddenAtLaunch: true,
          arguments: jsonEncode({
            'role': 'note',
            'summary': summary.toJson(),
          }),
        ),
      );
    } catch (e) {
      flog('[FloatingTab] 便签窗创建失败: $e');
      _noteWindow = null;
    }
  }

  /// 显示便签窗：首次创建时摘要随 arguments 注入、由便签引擎渲染首帧后自显示
  /// （避免白屏）；复用时推送最新摘要并直接显示。
  Future<void> _showNoteWindow(DesktopFloatingTaskSummary summary) async {
    final wasCreated = _noteWindow != null;
    await _ensureNoteWindow(summary);
    final note = _noteWindow;
    if (note == null) return;
    if (wasCreated) {
      // 复用：便签引擎常驻，handler 已注册，可安全推送并立即显示。
      await _notifyNote(summary);
      try {
        await note.show();
      } catch (e) {
        flog('[FloatingTab] 便签窗 show 失败: $e');
      }
    }
    // 首次创建：便签窗 hiddenAtLaunch，由便签引擎渲染首帧后自显示，避免白屏。
  }

  Future<void> _hideNoteWindow() async {
    final note = _noteWindow;
    if (note == null) return;
    try {
      await _noteUpdateChannel.invokeMethod('hideNote');
    } catch (_) {}
    try {
      await note.hide();
    } catch (_) {}
  }

  Future<void> _notifyNote(DesktopFloatingTaskSummary summary) async {
    try {
      await _noteUpdateChannel.invokeMethod('notifyTask', summary.toJson());
    } catch (e) {
      flog('[FloatingTab] notifyTask 失败: $e');
    }
  }

  /// 主窗注册便签窗 → 主窗的通道 handler（唤起主窗 / 便签关闭）。
  Future<void> _registerMainWindowChannel() async {
    if (_mainChannelRegistered) return;
    _mainChannelRegistered = true;
    try {
      await _noteCommandChannel.setMethodCallHandler((call) async {
        switch (call.method) {
          case 'showMain':
            final args = call.arguments;
            final openTaskId =
                (args is Map) ? args['openTaskId'] as String? : null;
            await restoreFullWindow(openTaskId: openTaskId);
            break;
          case 'dismissNote':
            await closeFloatingTab();
            break;
        }
      });
    } catch (e) {
      flog('[FloatingTab] 主窗通道注册失败: $e');
    }
  }

  Future<DesktopFloatingTaskSummary?> _selectTaskForFloatingTab() async {
    final repository = _taskRepository;
    if (repository == null) return null;

    // 用 getAllRaw() 取全量任务（含子任务），确保紧急的子任务也能被选中展示。
    final allTasks = await repository.getAllRaw();
    // 候选池 = 未完成任务（待办 status==0 + 进行中 status==1），
    // 无 startDate 的任务由 rankCandidates 剔除，故不再单独过滤。
    final activeTasks = allTasks
        .where(
          (task) =>
              (task.status == 0 || task.status == 1) &&
              task.deleted == 0 &&
              task.archived == 0,
        )
        .toList();

    final now = DateTime.now();
    final candidates = rankCandidates(activeTasks, now);
    if (candidates.isEmpty) return null;

    final top = candidates.first;
    return DesktopFloatingTaskSummary(
      taskId: top.id,
      title: top.title,
      priority: top.priority,
      anchorDate: anchorDateOf(top, now),
      dueDate: top.dueDate == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(top.dueDate!),
      extraTaskCount: candidates.length - 1,
    );
  }

  /// 任务锚点时间：startDate ?? dueDate ?? now。供便签展示用。
  @visibleForTesting
  static DateTime anchorDateOf(Task task, DateTime now) {
    if (task.startDate != null) {
      return DateTime.fromMillisecondsSinceEpoch(task.startDate!);
    }
    if (task.dueDate != null) {
      return DateTime.fromMillisecondsSinceEpoch(task.dueDate!);
    }
    return now;
  }

  /// 便签候选排序（分层规则，2026-08-03 确认）：
  /// 层① 小时级任务（单日非全天）优先；层② 跨天/全天任务（isAllDay || 跨日）靠后。
  /// 每层内：进行中(status==1)优先 → 距 startDate 最近 → 平局取 updatedAt 最新。
  /// 无 startDate 的任务不进入排序（直接从候选剔除）。
  @visibleForTesting
  static List<Task> rankCandidates(List<Task> pool, DateTime now) {
    final hourLevel = <Task>[];
    final multiDayLevel = <Task>[];
    for (final task in pool) {
      if (task.startDate == null) continue; // 无 startDate 不入排序
      if (task.isAllDay == 1 || _isMultiDayTask(task)) {
        multiDayLevel.add(task);
      } else {
        hourLevel.add(task);
      }
    }
    return [
      ..._rankWithinLayer(hourLevel, now),
      ..._rankWithinLayer(multiDayLevel, now),
    ];
  }

  static List<Task> _rankWithinLayer(List<Task> tasks, DateTime now) {
    int byTimeThenUpdated(Task a, Task b) {
      final distCompare = _startOf(a)
          .difference(now)
          .abs()
          .compareTo(_startOf(b).difference(now).abs());
      if (distCompare != 0) return distCompare;
      return b.updatedAt.compareTo(a.updatedAt);
    }

    final inProgress =
        tasks.where((t) => t.status == 1).toList()..sort(byTimeThenUpdated);
    final pending =
        tasks.where((t) => t.status != 1).toList()..sort(byTimeThenUpdated);
    return [...inProgress, ...pending];
  }

  /// 跨天判定：startDate 与 dueDate 不同日（与首页 _isMultiDayNode 语义一致）。
  static bool _isMultiDayTask(Task task) {
    final start = task.startDate;
    final due = task.dueDate;
    if (start == null || due == null) return false;
    final s = DateTime.fromMillisecondsSinceEpoch(start);
    final e = DateTime.fromMillisecondsSinceEpoch(due);
    return !(s.year == e.year && s.month == e.month && s.day == e.day);
  }

  static DateTime _startOf(Task task) =>
      DateTime.fromMillisecondsSinceEpoch(task.startDate!);
}
