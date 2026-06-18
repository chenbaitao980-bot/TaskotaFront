import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Alignment, MaterialPageRoute;
import 'package:window_manager/window_manager.dart';

import '../../core/router/app_router.dart';
import '../../core/utils/file_logger.dart';
import '../../core/utils/platform_utils.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/task_repository.dart';
import '../../presentation/pages/tasks/task_detail/task_detail_page.dart' as task_db;
import '../../services/local_storage_service.dart';
import 'window_state.dart';

enum DesktopWindowMode { full, floating }

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
}

class DesktopFloatingTabController extends ChangeNotifier {
  DesktopFloatingTabController._();

  static final DesktopFloatingTabController instance =
      DesktopFloatingTabController._();

  final LocalStorageService _storage = LocalStorageService();

  DesktopWindowMode _mode = DesktopWindowMode.full;
  DesktopFloatingTaskSummary? _currentTask;
  TaskRepository? _taskRepository;
  Rect? _lastFullBounds;
  bool _lastFullWasMaximized = false;
  bool _storageReady = false;
  bool _defaultEnabled = true;
  bool _dismissedUntilRestore = false;
  bool _isTransitioning = false;
  bool _canShowFloatingTab = false;

  DesktopWindowMode get mode => _mode;
  DesktopFloatingTaskSummary? get currentTask => _currentTask;
  bool get isFloating => _mode == DesktopWindowMode.floating;
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

  Future<void> handleCloseRequested() async {
    if (!isWindows || _isTransitioning) {
      flog('[FloatingTab] handleCloseRequested: 非Windows或转换中 -> hideToTray '
          '(isWindows=$isWindows, transitioning=$_isTransitioning)');
      await hideToTray();
      return;
    }
    await ensureInitialized();

    if (!_canShowFloatingTab || !_defaultEnabled || _dismissedUntilRestore) {
      flog('[FloatingTab] handleCloseRequested: 闸门未通过 -> hideToTray '
          '(canShow=$_canShowFloatingTab, enabled=$_defaultEnabled, '
          'dismissed=$_dismissedUntilRestore)');
      await hideToTray();
      return;
    }

    final candidate = await _selectTaskForFloatingTab();
    if (candidate == null) {
      flog('[FloatingTab] handleCloseRequested: 无未完成任务候选 -> hideToTray');
      await hideToTray();
      return;
    }

    flog('[FloatingTab] handleCloseRequested: 命中候选 taskId=${candidate.taskId} '
        'title="${candidate.title}" extra=${candidate.extraTaskCount} -> 进入悬浮模式');
    await _enterFloatingMode(candidate);
  }

  Future<void> restoreFullWindow({String? openTaskId}) async {
    if (!isWindows || _isTransitioning) return;
    _dismissedUntilRestore = false;
    if (_mode == DesktopWindowMode.floating) {
      await _restoreWindowChromeAndBounds();
    }

    await windowManager.show();
    await windowManager.focus();
    desktopWindowVisible = true;

    if (openTaskId != null && openTaskId.isNotEmpty) {
      _openTaskDetail(openTaskId);
    }
  }

  Future<void> closeFloatingTab() async {
    _dismissedUntilRestore = true;
    if (_mode == DesktopWindowMode.floating) {
      await _restoreWindowChromeAndBounds();
    }
    await hideToTray();
  }

  Future<void> hideToTray() async {
    desktopWindowVisible = false;
    await windowManager.hide();
  }

  Future<void> _enterFloatingMode(DesktopFloatingTaskSummary summary) async {
    _isTransitioning = true;
    try {
      _lastFullBounds = await windowManager.getBounds();
      _lastFullWasMaximized = await windowManager.isMaximized();
      if (_lastFullWasMaximized) {
        await windowManager.unmaximize();
      }

      _currentTask = summary;
      _mode = DesktopWindowMode.floating;
      notifyListeners();

      await windowManager.setTitleBarStyle(
        TitleBarStyle.hidden,
        windowButtonVisibility: false,
      );
      await windowManager.setResizable(false);
      await windowManager.setAlwaysOnTop(true);
      await windowManager.setSkipTaskbar(true);
      await windowManager.setSize(const Size(320, 88));
      await windowManager.setAlignment(Alignment.topRight);
      await windowManager.show();
      await windowManager.focus();
      desktopWindowVisible = true;
    } finally {
      _isTransitioning = false;
    }
  }

  Future<void> _restoreWindowChromeAndBounds() async {
    _isTransitioning = true;
    try {
      _mode = DesktopWindowMode.full;
      _currentTask = null;
      notifyListeners();

      await windowManager.setSkipTaskbar(false);
      await windowManager.setAlwaysOnTop(false);
      await windowManager.setResizable(true);
      await windowManager.setTitleBarStyle(
        TitleBarStyle.normal,
        windowButtonVisibility: true,
      );

      if (_lastFullBounds != null) {
        await windowManager.setBounds(_lastFullBounds);
      }
      if (_lastFullWasMaximized) {
        await windowManager.maximize();
      }
    } finally {
      _isTransitioning = false;
    }
  }

  Future<DesktopFloatingTaskSummary?> _selectTaskForFloatingTab() async {
    final repository = _taskRepository;
    if (repository == null) return null;

    // 用 getAllRaw() 取全量任务（含子任务），比 getAll() 多了子任务，
    // 确保紧急的子任务也能被选中展示。
    final allTasks = await repository.getAllRaw();
    final activeTasks = allTasks
        .where((task) =>
            task.status == 0 && task.deleted == 0 && task.archived == 0)
        .toList();
    if (activeTasks.isEmpty) return null;

    // 有子任务就只看子任务：子任务是可执行的工作项，父任务仅作回退。
    final childTasks =
        activeTasks.where((t) => t.parentId != null).toList();
    final candidates = childTasks.isNotEmpty
        ? childTasks
        : activeTasks.where((t) => t.parentId == null).toList();
    if (candidates.isEmpty) return null;

    final now = DateTime.now();
    candidates.sort((left, right) {
      final scoreCompare = _scoreTask(
        right,
        now,
      ).compareTo(_scoreTask(left, now));
      if (scoreCompare != 0) return scoreCompare;

      final leftDate = _anchorDate(left, now);
      final rightDate = _anchorDate(right, now);
      final dateCompare = leftDate.compareTo(rightDate);
      if (dateCompare != 0) return dateCompare;

      return right.updatedAt.compareTo(left.updatedAt);
    });

    final top = candidates.first;
    return DesktopFloatingTaskSummary(
      taskId: top.id,
      title: top.title,
      priority: top.priority,
      anchorDate: _anchorDate(top, now),
      dueDate: top.dueDate == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(top.dueDate!),
      extraTaskCount: candidates.length - 1,
    );
  }

  DateTime _anchorDate(Task task, DateTime now) {
    if (task.startDate != null) {
      return DateTime.fromMillisecondsSinceEpoch(task.startDate!);
    }
    if (task.dueDate != null) {
      return DateTime.fromMillisecondsSinceEpoch(task.dueDate!);
    }
    return now;
  }

  int _scoreTask(Task task, DateTime now) {
    final anchor = _anchorDate(task, now);
    final days = anchor.difference(now).inDays;
    final urgency = days < 0
        ? 10
        : days <= 3
        ? 5
        : days <= 7
        ? 2
        : days <= 30
        ? 0
        : -2;
    return task.priority * 2 + urgency;
  }

  Future<void> _openTaskDetail(String taskId) async {
    // 从数据库取完整 Task 对象，导航到数据库版 TaskDetailPage
    // （不能用 /task/:id 路由——那是本地 JSON 版详情页，数据源不同）
    final task = await _taskRepository?.get(taskId);
    if (task == null) {
      flog('[FloatingTab] _openTaskDetail: taskId=$taskId 在数据库中未找到');
      return;
    }

    scheduleMicrotask(() {
      final navigator = AppRouter.navigatorKey.currentState;
      navigator?.pushNamedAndRemoveUntil('/', (route) => false);
      Future<void>.delayed(const Duration(milliseconds: 100), () {
        AppRouter.navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => task_db.TaskDetailPage(task: task),
          ),
        );
      });
    });
  }
}
