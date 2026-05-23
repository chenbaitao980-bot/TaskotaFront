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
你是用户的 AI 日程管家。你的核心任务是帮助用户拆解大目标。

## 渐进式引导规则（必须严格遵守）

1. **每次只问一个最关键的问题**，不要一次性列出所有问题
2. 从最重要到次要逐步收窄：目标理解 → 当前水平 → 可用时间 → 截止日期 → 其他约束
3. 用简洁的自然对话方式提问，不要结构化列表

## 建议回复选项（必须遵守）

当你的消息以"？"或"？"结尾时，必须在回复**末尾**添加一行建议回复选项：

[OPTIONS: 选项A | 选项B | 选项C]

根据当前提问内容生成3个最合适的选项，示例：
- 问水平/基础 → [OPTIONS: 零基础 | 会一点点 | 有基础]
- 问时间/频率 → [OPTIONS: 每天30分钟 | 每天1小时 | 每天2小时以上]
- 问目标/程度 → [OPTIONS: 简单入门就好 | 达到中级水平 | 希望精通]
- 确认理解 → [OPTIONS: 是的，没错 | 不太准确 | 让我重新说]

选项要简短（2-6字），用半角 | 分隔。

## 拆解框架
最终交付三层拆解：
- 战略层：季度里程碑
- 战术层：每月关键交付
- 执行层：每周具体任务

## 对话阶段判断

### 第1轮（用户刚输入目标）
- 先简洁确认你理解的目标
- 只问 1 个最关键的问题（如"你目前在这个领域是什么水平？"）
- 不要问其他问题，不要给建议

### 第2轮（用户已回答第一轮）
- 简短认可用户的回答
- 只问下 1 个关键问题（如"你每周大约能投入多少时间？"）

### 第3轮
- 只问最后 1 个关键问题（如"你希望什么时间完成？"）

### 信息充足后
- 输出完整三层拆解计划
- 格式：用 Markdown 结构清晰展示
- 结尾询问"这个计划可以吗？需要调整哪里？"

## 日程解析（非目标拆解时）
如果用户只是描述一个日程时间，解析为 JSON：
{"type": "schedule", "title": "...", "start_time": "ISO8601", "end_time": "ISO8601", "priority": "P2"}

始终用中文回复。保持对话自然流畅，像真人助手一样。

## 用户画像（系统自动注入）
{user_profile}
''';

  Future<String> chat({
    required String userMessage,
    List<Map<String, String>> history = const [],
    Map<String, dynamic>? userProfile,
  }) async {
    final prompt = userProfile != null && userProfile.isNotEmpty
        ? _systemPrompt.replaceFirst('{user_profile}', _formatProfile(userProfile))
        : _systemPrompt.replaceFirst('{user_profile}', '暂无用户画像，请通过引导式提问获取。\n');

    final messages = <Map<String, String>>[
      {'role': 'system', 'content': prompt},
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

  String _formatProfile(Map<String, dynamic> profile) {
    final buf = StringBuffer();
    if (profile['name'] != null) buf.writeln('- 姓名：${profile['name']}');
    if (profile['occupation'] != null) buf.writeln('- 职业：${profile['occupation']}');
    if (profile['goals'] != null) {
      final goals = profile['goals'] as List;
      buf.writeln('- 目标：${goals.join('、')}');
    }
    if (profile['levels'] != null) {
      final levels = profile['levels'] as List;
      final goals = profile['goals'] as List? ?? [];
      for (var i = 0; i < levels.length && i < goals.length; i++) {
        buf.writeln('- ${goals[i]} 当前水平：${levels[i]}');
      }
    }
    buf.writeln('- 任务完成率：${((profile['completionRate'] as num?) ?? 0.0).toStringAsFixed(0)}%');
    return buf.toString();
  }

  /// Conflict analysis
  Future<Map<String, dynamic>?> analyzeConflict({
    required Map<String, dynamic> newSchedule,
    required Map<String, dynamic> existingSchedule,
    Map<String, dynamic>? userProfile,
  }) async {
    final profileText = userProfile != null ? _formatProfile(userProfile) : '暂无';
    final messages = [
      {
        'role': 'system',
        'content': '''你是日程冲突分析师。用户要新增一个日程，但与现有日程时间重叠。
请给出3个推荐选项，每个选项包含：action(方案描述), risk(风险), benefit(收益)。
只输出JSON格式：{"options":[{"action":"...","risk":"...","benefit":"..."},...]}

用户画像：
$profileText''',
      },
      {
        'role': 'user',
        'content': '新日程：${newSchedule['title']} (${newSchedule['start']}~${newSchedule['end']})\n冲突日程：${existingSchedule['title']} (${existingSchedule['start']}~${existingSchedule['end']})\n请给出3个处理方案。',
      },
    ];

    try {
      final response = await _dio.post('', data: {
        'model': 'deepseek-chat',
        'messages': messages,
        'temperature': 0.5,
        'max_tokens': 1024,
      });
      final content = response.data['choices'][0]['message']['content'] as String;
      final match = RegExp(r'\{.*\}', dotAll: true).firstMatch(content);
      if (match == null) return null;
      return json.decode(match.group(0)!) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Parse user input to determine if it's a schedule or a goal
  Future<Map<String, dynamic>?> parseSchedule(String text) async {
    final messages = [
      {
        'role': 'system',
        'content': '''你是日程解析器。只输出严格JSON。
如果用户输入是明确时间日程（如"明天下午3点开会"），输出：
{"type": "schedule", "title": "...", "start_time": "ISO8601", "end_time": "ISO8601", "priority": "P2"}
如果是目标/愿望（如"我想学日语"），输出：
{"type": "goal", "title": "...", "description": "..."}
当前时间: ${DateTime.now().toIso8601String()}。只输出JSON。'''
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
