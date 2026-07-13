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
    DateTime? now,
  }) async {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return const LazyLogResult();
    if (!config.isComplete) {
      return _fallback(trimmed);
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
            {'role': 'system', 'content': _systemPrompt(now ?? DateTime.now())},
            {'role': 'user', 'content': trimmed},
          ],
        },
      );
      final content = _readContent(response.data);
      final decoded = jsonDecode(_stripFence(content));
      if (decoded is! Map) return _fallback(trimmed);
      final result = LazyLogResult.fromJson(
        decoded.map((key, value) => MapEntry(key.toString(), value)),
      );
      return result.isEmpty ? _fallback(trimmed) : result;
    } catch (_) {
      return _fallback(trimmed);
    }
  }

  String _systemPrompt(DateTime now) {
    final today = _dateOnly(now);
    return '''
你是 Taskora 首页懒人日志结构化助手。把用户随手输入整理成 JSON，不要输出 Markdown，不要解释。

当前日期：$today

JSON 格式必须是：
{
  "summary": "一句话总结",
  "completed": ["已完成或已有进展的事实"],
  "blockers": ["问题、阻塞、风险或报错"],
  "nextActions": ["下一步行动"],
  "tasks": [
    {
      "title": "任务标题",
      "description": "可选说明",
      "priority": "P0|P1|P2|P3",
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
2. 没有明确时间的内容放入 tasks，不要放入 schedules。
3. 用户明确说“明天/今天/下午/晚上/几点”时，结合当前日期转换为 ISO-8601。
4. 任务标题要短，适合直接进入待办列表。
5. 如果某类没有内容，返回空数组。
''';
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
