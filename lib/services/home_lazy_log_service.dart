import 'dart:convert';

import 'package:dio/dio.dart';

import '../models/assistant/assistant_models.dart';
import '../models/assistant/lazy_log_models.dart';

class HomeLazyLogService {
  final Dio _dio;

  HomeLazyLogService({Dio? dio})
    : _dio =
          dio ?? Dio(BaseOptions(connectTimeout: const Duration(seconds: 30)));

  Future<LazyLogResult> structure({
    required AssistantModelConfig config,
    required String input,
    String projectRoutingContext = '',
    DateTime? now,
  }) async {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return const LazyLogResult();
    if (!config.isComplete) {
      return _normalizeRelativeTaskRanges(
        _fallback(trimmed),
        input: trimmed,
        now: now ?? DateTime.now(),
      );
    }

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        config.endpoint,
        options: Options(
          headers: {
            'Authorization': 'Bearer ${config.apiKey.trim()}',
            'Content-Type': 'application/json',
          },
        ),
        data: {
          'model': config.model.trim(),
          'temperature': 0.2,
          'messages': [
            {
              'role': 'system',
              'content': _systemPrompt(
                now ?? DateTime.now(),
                config.userInstructions,
                projectRoutingContext,
              ),
            },
            {'role': 'user', 'content': trimmed},
          ],
        },
      );
      final content = _readContent(response.data);
      final decoded = jsonDecode(_stripFence(content));
      if (decoded is! Map) {
        return _normalizeRelativeTaskRanges(
          _fallback(trimmed),
          input: trimmed,
          now: now ?? DateTime.now(),
        );
      }
      final result = LazyLogResult.fromJson(
        decoded.map((key, value) => MapEntry(key.toString(), value)),
      );
      return result.isEmpty
          ? _normalizeRelativeTaskRanges(
              _fallback(trimmed),
              input: trimmed,
              now: now ?? DateTime.now(),
            )
          : _normalizeRelativeTaskRanges(
              result,
              input: trimmed,
              now: now ?? DateTime.now(),
            );
    } catch (_) {
      return _normalizeRelativeTaskRanges(
        _fallback(trimmed),
        input: trimmed,
        now: now ?? DateTime.now(),
      );
    }
  }

  String _systemPrompt(
    DateTime now,
    String userInstructions,
    String projectRoutingContext,
  ) {
    final today = _dateOnly(now);
    final preferences = _userInstructionsBlock(userInstructions);
    final projectRouting = _projectRoutingBlock(projectRoutingContext);
    return '''
你是 Taskora 首页懒人日志结构化助手。把用户随手输入整理成 JSON，不要输出 Markdown，不要解释。

当前日期：$today

JSON 格式必须是：
{
	  "summary": "一句话总结",
	  "completed": ["已完成或已有进展的事实"],
	  "blockers": ["问题、阻塞、风险或报错"],
	  "nextActions": ["下一步行动"],
	  "parentTitle": "可选，上下文主题或父任务标题，例如 SRM相关内容",
	  "projectGroupHint": "可选，必须来自可用项目分组名称；不确定则空字符串",
	  "projectHint": "可选，必须来自可用项目名称；不确定则空字符串",
	  "tasks": [
    {
      "title": "任务标题",
      "description": "可选说明，必要时写清背景、目标、交付物或注意事项",
      "priority": "P0|P1|P2|P3",
      "checklist": ["可选检查点，步骤较多或较复杂时填写"],
      "startTime": "可选 ISO-8601 时间",
      "dueTime": "可选 ISO-8601 时间"
    }
  ],
  "schedules": [
    {
      "title": "日程标题",
      "description": "可选说明",
      "priority": "P0|P1|P2|P3",
      "startTime": "必填 ISO-8601 时间",
      "endTime": "必填 ISO-8601 时间"
    }
  ]
}

规则：
1. 只基于用户输入，不得编造不存在的任务、时间、人员、原因、结果。
2. 所有需要创建的事项都放入 tasks；即使有明确时间，也写入 tasks.startTime/dueTime，不要放入 schedules。
3. 用户明确说“明天/今天/下午/晚上/几点”时，结合当前日期转换为 ISO-8601。
4. 用户说“这周/本周/这星期/本星期”且没有明确几点时，创建跨天周任务区间：startTime 用本周一 09:00，dueTime 用本周日 18:00；不要把它压成周日 23:59 或最后一小时。
5. 任务标题要短，适合直接进入待办列表。
6. 如果输入里出现“关于xxx”“xxx相关内容”“某项目/模块/供应商/客户”等上下文，把它提炼为 parentTitle。
7. 如果提供了可用项目分组/项目列表，只能基于这些真实名称填写 projectGroupHint/projectHint；不要编造项目名。
8. 当输入明显更像某个分组或项目，但项目名没有字面出现时，也可以根据语义选择最贴近的真实项目；不确定时保持空字符串，交给用户在预览里选择。
9. schedules 只为兼容旧格式保留，默认返回空数组。
10. 创建任务时，如果用户输入包含背景、目标、交付物、约束或原因，顺带生成 description；如果任务步骤比较多、验收点明确或执行较复杂，生成 checklist 检查点。
11. 如果某类没有内容，返回空数组。
$preferences
$projectRouting
''';
  }

  String _userInstructionsBlock(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';
    return '''

用户自定义 CLAUDE.md 偏好：
$trimmed
请在不违反上方 JSON 格式和任务创建规则的前提下遵循这些偏好。''';
  }

  String _projectRoutingBlock(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';
    return '''

可用项目分组和项目：
$trimmed

请优先使用这里的真实分组/项目名称填写 projectGroupHint/projectHint。''';
  }

  LazyLogResult _normalizeRelativeTaskRanges(
    LazyLogResult result, {
    required String input,
    required DateTime now,
  }) {
    if (!_hasCurrentWeekPhrase(input) || _hasExplicitClock(input)) {
      return result;
    }

    final weekStartDate = _startOfWeek(now);
    final weekStart = DateTime(
      weekStartDate.year,
      weekStartDate.month,
      weekStartDate.day,
      9,
    );
    final weekEnd = DateTime(
      weekStartDate.year,
      weekStartDate.month,
      weekStartDate.day + 6,
      18,
    );
    final tasks = result.tasks.map((task) {
      if (!_shouldUseWeekRange(task, weekStartDate)) return task;
      return task.copyWith(startTime: weekStart, dueTime: weekEnd);
    }).toList();

    return LazyLogResult(
      summary: result.summary,
      completed: result.completed,
      blockers: result.blockers,
      nextActions: result.nextActions,
      tasks: tasks,
      schedules: result.schedules,
      parentTitle: result.parentTitle,
      projectHint: result.projectHint,
      projectGroupHint: result.projectGroupHint,
      usedFallback: result.usedFallback,
    );
  }

  bool _shouldUseWeekRange(LazyLogTaskDraft task, DateTime weekStartDate) {
    final start = task.startTime;
    final due = task.dueTime;
    if (start == null || due == null) return true;
    if (due.difference(start) < const Duration(days: 1)) return true;
    return _isSameDate(due, weekStartDate.add(const Duration(days: 6))) &&
        due.hour >= 22;
  }

  DateTime _startOfWeek(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    return day.subtract(Duration(days: date.weekday - DateTime.monday));
  }

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _hasCurrentWeekPhrase(String input) {
    return _containsAny(input, const ['这周', '本周', '这星期', '本星期']);
  }

  bool _hasExplicitClock(String input) {
    return RegExp(
      r'(\d{1,2}[:：]\d{2}|\d{1,2}\s*点|上午|中午|下午|晚上)',
    ).hasMatch(input);
  }

  LazyLogResult _fallback(String input) {
    final lines = input
        .split(RegExp(r'[\r\n。；;]+'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    final completed = <String>[];
    final blockers = <String>[];
    final nextActions = <String>[];
    final tasks = <LazyLogTaskDraft>[];

    for (final line in lines) {
      if (_containsAny(line, const [
        '问题',
        '阻塞',
        '报错',
        '失败',
        '异常',
        '风险',
        '卡住',
      ])) {
        blockers.add(line);
      } else if (_containsAny(line, const [
        '明天',
        '计划',
        '接下来',
        '后续',
        '待办',
        '准备',
        '这周',
        '本周',
        '这星期',
        '本星期',
      ])) {
        nextActions.add(line);
        tasks.add(LazyLogTaskDraft(title: _taskTitle(line), description: line));
      } else {
        completed.add(line);
      }
    }

    return LazyLogResult(
      summary: lines.isEmpty ? input : lines.first,
      completed: completed,
      blockers: blockers,
      nextActions: nextActions,
      tasks: tasks,
      usedFallback: true,
    );
  }

  bool _containsAny(String value, List<String> keywords) {
    return keywords.any(value.contains);
  }

  String _taskTitle(String value) {
    final normalized = value
        .replaceFirst(RegExp(r'^(明天|今天|接下来|后续|计划|待办)[:：，,\s]*'), '')
        .trim();
    if (normalized.isEmpty) return value;
    return normalized.length <= 36
        ? normalized
        : '${normalized.substring(0, 36)}...';
  }

  String _readContent(Map<String, dynamic>? data) {
    final choices = data?['choices'];
    if (choices is List && choices.isNotEmpty) {
      final first = choices.first;
      if (first is Map) {
        final message = first['message'];
        if (message is Map) return message['content']?.toString() ?? '';
      }
    }
    final output = data?['output'];
    if (output is String) return output;
    return '';
  }

  String _stripFence(String value) {
    final trimmed = value.trim();
    final match = RegExp(
      r'^```(?:json)?\s*([\s\S]*?)\s*```$',
      caseSensitive: false,
    ).firstMatch(trimmed);
    return match?.group(1)?.trim() ?? trimmed;
  }

  String _dateOnly(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }
}
