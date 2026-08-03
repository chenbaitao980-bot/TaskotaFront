import 'dart:convert';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../../../core/desktop/desktop_floating_tab_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/file_logger.dart';
import '../../widgets/desktop_floating_task_tab.dart';

/// 主窗 → 便签窗通道（便签引擎注册 handler，主窗 invoke 推送更新/隐藏）。
const WindowMethodChannel _noteUpdateChannel = WindowMethodChannel(
  'taskora_note_update',
  mode: ChannelMode.unidirectional,
);

/// 便签窗 → 主窗通道（主窗注册 handler，便签窗 invoke 唤起/关闭）。
const WindowMethodChannel _noteCommandChannel = WindowMethodChannel(
  'taskora_note_command',
  mode: ChannelMode.unidirectional,
);

/// 便签摘要状态：初始由 create arguments 注入，后续由 notifyTask 通道更新。
final ValueNotifier<DesktopFloatingTaskSummary?> noteSummaryNotifier =
    ValueNotifier<DesktopFloatingTaskSummary?>(null);

/// 便签引擎入口：独立第二 Flutter 引擎，仅由 main() 在检测到 role==note 时调用。
/// 只做窗口 chrome 初始化 + 通道注册 + 渲染便签卡片，不初始化业务服务。
Future<void> runNoteWindow() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _registerNoteChannelHandler();
  await _loadInitialSummary();
  runApp(const NoteWindowApp());
  // 窗口以 hiddenAtLaunch 创建。首帧渲染完成后再初始化样式并显示，
  // 保证用户看到的便签已渲染完成（否则短暂白屏）。
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    try {
      await _initNoteWindowChrome();
    } catch (e) {
      flog('[NoteWindow] 便签窗 chrome 初始化失败: $e');
    }
  });
}

/// 从 create arguments 读初始摘要。创建即携带，规避首次 notifyTask 的注册竞态。
Future<void> _loadInitialSummary() async {
  try {
    final controller = await WindowController.fromCurrentEngine();
    if (controller.arguments.isEmpty) return;
    final decoded = jsonDecode(controller.arguments);
    if (decoded is Map && decoded['role'] == 'note' && decoded['summary'] is Map) {
      noteSummaryNotifier.value = DesktopFloatingTaskSummary.fromJson(
        Map<String, dynamic>.from(decoded['summary'] as Map),
      );
    }
  } catch (e) {
    // 初始摘要缺失时保持空白，等待 notifyTask 推送。
  }
}

/// 接收主窗推送的摘要更新与隐藏指令。
Future<void> _registerNoteChannelHandler() async {
  await _noteUpdateChannel.setMethodCallHandler((call) async {
    switch (call.method) {
      case 'notifyTask':
        noteSummaryNotifier.value = _parseSummary(call.arguments);
        break;
      case 'hideNote':
        try {
          final controller = await WindowController.fromCurrentEngine();
          await controller.hide();
        } catch (_) {}
        break;
    }
  });
}

DesktopFloatingTaskSummary? _parseSummary(dynamic raw) {
  try {
    if (raw is String) {
      return DesktopFloatingTaskSummary.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    }
    if (raw is Map) {
      return DesktopFloatingTaskSummary.fromJson(
        Map<String, dynamic>.from(raw),
      );
    }
  } catch (_) {}
  return null;
}

/// 透明无边框 360x112 置顶跳过任务栏，右上角对齐。
/// setBackgroundColor(透明) 触发窗口 ACCENT 透明，消除 OS 深色非客户区边框（黑线根因）。
Future<void> _initNoteWindowChrome() async {
  await windowManager.ensureInitialized();
  await windowManager.setBackgroundColor(const Color(0x00000000));
  await windowManager.setTitleBarStyle(
    TitleBarStyle.hidden,
    windowButtonVisibility: false,
  );
  await windowManager.setResizable(false);
  await windowManager.setAlwaysOnTop(true);
  // 必须先初始化 taskbar_（CoCreateInstance），否则 setSkipTaskbar
  // 解引用空指针导致 window_manager_plugin.dll 崩溃（0xc0000005）。
  await windowManager.waitUntilReadyToShow();
  await windowManager.setSkipTaskbar(true);
  await windowManager.setMinimumSize(const Size(360, 112));
  await windowManager.setMaximumSize(const Size(360, 112));
  await windowManager.setSize(const Size(360, 112));
  await windowManager.setAlignment(Alignment.topRight);
  await windowManager.setPreventClose(true);
  // 首帧渲染完成后才显示，避免用户看到白屏窗口。
  await windowManager.show();
}

class NoteWindowApp extends StatelessWidget {
  const NoteWindowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Taskora 便签',
      theme: AppTheme.themeData,
      darkTheme: AppTheme.themeData,
      themeMode: AppTheme.current.isDark ? ThemeMode.dark : ThemeMode.light,
      home: const _NoteWindowHome(),
    );
  }
}

class _NoteWindowHome extends StatelessWidget {
  const _NoteWindowHome();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ValueListenableBuilder<DesktopFloatingTaskSummary?>(
        valueListenable: noteSummaryNotifier,
        builder: (context, summary, _) {
          if (summary == null) return const SizedBox.shrink();
          return DesktopFloatingTaskTab(
            task: summary,
            onTap: () => _openMainWindow(summary.taskId),
            onClose: _dismissNoteWindow,
          );
        },
      ),
    );
  }
}

/// 点便签：自隐 + 通知主窗 showMain（携带任务 id 供首页定位）。
Future<void> _openMainWindow(String taskId) async {
  try {
    final controller = await WindowController.fromCurrentEngine();
    await controller.hide();
  } catch (_) {}
  try {
    await _noteCommandChannel.invokeMethod('showMain', {'openTaskId': taskId});
  } catch (_) {}
}

/// 点关闭：自隐 + 通知主窗 dismissNote（主窗保持隐藏，下次关闭不弹便签）。
Future<void> _dismissNoteWindow() async {
  try {
    final controller = await WindowController.fromCurrentEngine();
    await controller.hide();
  } catch (_) {}
  try {
    await _noteCommandChannel.invokeMethod('dismissNote');
  } catch (_) {}
}
