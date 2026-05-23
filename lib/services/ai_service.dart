import 'dart:convert';
import 'package:dio/dio.dart';
import '../core/constants/app_constants.dart';

class AIService {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: AppConstants.deepseekApiUrl,
    headers: {
      'Authorization': 'Bearer ${AppConstants.deepseekApiKey}',
      'Content-Type': 'application/json',
    },
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 60),
  ));

  static const _systemPrompt = '''
你是用户的AI日程管家。你的任务是帮助用户拆解大目标为可执行的步骤。

当用户提出目标时（如"我想今年拿下日语N1"）：
1. 先询问必要信息（当前水平、可用时间、截止日期等）
2. 然后输出三层拆解：
   - 战略层：季度里程碑
   - 战术层：每月关键交付
   - 执行层：每周具体任务

如果用户只是描述一个日程（如"明天下午3点开会"、"下周三上午去医院"），直接解析为JSON格式的日程：
{"type": "schedule", "title": "会议", "start_time": "2026-05-24T15:00:00", "end_time": "2026-05-24T16:00:00", "priority": "P2", "note": "..."}

如果用户想拆解目标，输出包含任务拆解的JSON：
{"type": "task_breakdown", "goal": "...", "quarters": [{"quarter": "Q1", "milestone": "...", "months": [{"month": "1月", "tasks": ["..."]}]}]}

请始终用中文回复，保持简洁实用。
''';

  Future<String> chat({
    required String userMessage,
    List<Map<String, String>> history = const [],
  }) async {
    final messages = <Map<String, String>>[
      {'role': 'system', 'content': _systemPrompt},
      ...history,
      {'role': 'user', 'content': userMessage},
    ];

    final response = await _dio.post('', data: {
      'model': 'deepseek-chat',
      'messages': messages,
      'temperature': 0.7,
      'max_tokens': 2048,
    });

    return response.data['choices'][0]['message']['content'] as String;
  }

  Future<Map<String, dynamic>?> parseSchedule(String text) async {
    final messages = [
      {
        'role': 'system',
        'content': '''你是一个日程解析器。从用户输入的自然语言中提取日程信息，输出严格JSON格式。
如果用户输入的是"明天下午3点开会"这种明确日程，输出：
{"type": "schedule", "title": "会议标题", "start_time": "ISO8601时间", "end_time": "ISO8601时间(默认+1小时)", "priority": "P2"}

如果用户输入的是目标（如"我想学日语"），输出：
{"type": "goal", "title": "学日语", "description": "用户想学日语"}

只输出JSON，不要其他文字。当前时间是${DateTime.now().toIso8601String()}，请据此计算相对时间。'''
      },
      {'role': 'user', 'content': text},
    ];

    final response = await _dio.post('', data: {
      'model': 'deepseek-chat',
      'messages': messages,
      'temperature': 0.3,
      'max_tokens': 1024,
    });

    final content = response.data['choices'][0]['message']['content'] as String;
    final jsonStr = content.trim().replaceAll(RegExp(r'^```json\s*|```$'), '');
    final match = RegExp(r'\{.*\}', dotAll: true).firstMatch(jsonStr);
    if (match == null) return null;

    try {
      return json.decode(match.group(0)!) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}
