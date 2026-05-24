import 'dart:convert';
import 'package:dio/dio.dart';
import '../core/constants/app_constants.dart';

class AIService {
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: AppConstants.deepseekApiUrl,
      headers: {
        'Authorization': 'Bearer ${AppConstants.deepseekApiKey}',
        'Content-Type': 'application/json',
      },
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
    ),
  );

  static const _systemPrompt = '''
你是用户的 AI 日程管家。你的核心任务是帮助用户拆解大目标，或者直接识别日程安排。

## 回复格式要求（禁止项）

对话中只能出现两类内容：
1. 自然的中文对话文字
2. 在提问末尾加一行 [OPTIONS: 选项A | 选项B | 选项C] 供 UI 渲染选项卡

**绝对禁止输出以下内容（严重违规）：**
- 步骤编号（如"step1"、"第1步"、"step1"、"步骤1"）
- 技术术语（如"diagnose_goal"、"classify_missing_slots"、"route_assignment"、"TaskFlow"等）
- UI 标记（如 [TABLE_BEGIN]、[TABLE_END]、[HIERARCHY_BEGIN]、[HIERARCHY_END]）
- 任何 `###` 或 `##` 标题标记

你的每一条回复都要像和朋友聊天一样自然，不能带任何技术痕迹。

## 规划对话流程（仅内部遵循，不要输出）

按以下步骤走，但**每一步都只用自然语言表达**：

1. 先简单确认你理解用户的目标（一句话即可）
2. 内心判断：当前水平、可用时间、截止日期、其他约束、偏好安排中哪些信息缺失
3. 从缺失信息中选最重要的一条，用自然语气只问这一个问题
4. 在问题末尾加 [OPTIONS:] 提供3个简短选项（2-6字，半角|分隔）
5. 用户回答后，再问下一个问题，以此类推
6. 信息收集足够后，输出完整计划：先一个 Markdown 表格（|阶段|任务|时间范围|说明|），再一个缩进列表展示层级结构。不需要任何前后标记。
7. 最后问用户"这个计划可以吗？需要调整哪里？"

## 对话上下文规则

如果用户中途换了话题（例如先说了"踢足球"又说了"弹吉他"），则立即清空之前的话题，专注于新话题。不要混用不同话题的信息。

## 日程识别规则

当用户输入明显是一个具体日程（如"明天下午3点开会"、"今天晚上吃饭"等含明确时间和动作的），输出 JSON：
{"type": "schedule", "title": "...", "start_time": "ISO8601", "end_time": "ISO8601", "priority": "P2"}

如果用户输入的是一个目标/愿望（如"想学日语"、"练好踢足球"、"学会弹吉他"等），按上述规划流程走。
如果是"这周踢足球"、"周末弹吉他"这类模糊安排，按目标规划走，不要直接当日程处理。
如果有歧义，优先按目标规划处理，并用自然语言向用户确认。

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
        ? _systemPrompt.replaceFirst(
            '{user_profile}',
            _formatProfile(userProfile),
          )
        : _systemPrompt.replaceFirst('{user_profile}', '暂无用户画像，请通过引导式提问获取。\n');

    final messages = <Map<String, String>>[
      {'role': 'system', 'content': prompt},
      ...history,
      {'role': 'user', 'content': userMessage},
    ];

    final response = await _dio.post(
      '',
      data: {
        'model': 'deepseek-chat',
        'messages': messages,
        'temperature': 0.7,
        'max_tokens': 2048,
      },
    );

    return response.data['choices'][0]['message']['content'] as String;
  }

  String _formatProfile(Map<String, dynamic> profile) {
    final buf = StringBuffer();
    if (profile['name'] != null) {
      buf.writeln('- 姓名：${profile['name']}');
    }
    if (profile['occupation'] != null) {
      buf.writeln('- 职业：${profile['occupation']}');
    }
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
    buf.writeln(
      '- 任务完成率：${((profile['completionRate'] as num?) ?? 0.0).toStringAsFixed(0)}%',
    );
    return buf.toString();
  }

  /// Conflict analysis
  Future<Map<String, dynamic>?> analyzeConflict({
    required Map<String, dynamic> newSchedule,
    required Map<String, dynamic> existingSchedule,
    Map<String, dynamic>? userProfile,
  }) async {
    final profileText = userProfile != null
        ? _formatProfile(userProfile)
        : '暂无';
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
        'content':
            '新日程：${newSchedule['title']} (${newSchedule['start']}~${newSchedule['end']})\n冲突日程：${existingSchedule['title']} (${existingSchedule['start']}~${existingSchedule['end']})\n请给出3个处理方案。',
      },
    ];

    try {
      final response = await _dio.post(
        '',
        data: {
          'model': 'deepseek-chat',
          'messages': messages,
          'temperature': 0.5,
          'max_tokens': 1024,
        },
      );
      final content =
          response.data['choices'][0]['message']['content'] as String;
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
如果是模糊目标（如"踢足球"、"弹吉他"），按 goal 处理。
当前时间: ${DateTime.now().toIso8601String()}。只输出JSON。''',
      },
      {'role': 'user', 'content': text},
    ];

    final response = await _dio.post(
      '',
      data: {
        'model': 'deepseek-chat',
        'messages': messages,
        'temperature': 0.3,
        'max_tokens': 1024,
      },
    );

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
