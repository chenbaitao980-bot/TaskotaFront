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

## JSON 输出格式（**硬性要求，必须遵守**）

你的每一条回复都必须是一个 JSON 对象，包含 message 和 options 两个字段：

```json
{
    "message": "你的对话回复文字",
    "options": ["选项A", "选项B", "选项C"]
}
```

### 规则
- **向用户提问时**：在 message 中写问题，在 options 中提供 2~3 个简短选项（每个 2~8 个字）
- **仅回复/确认时**：message 中写文字，options 设为空数组 []
- **输出计划时**：message 中包含 Markdown 表格、流程节点、准备清单、核心要点、训练进度；最后仍要在 options 提供 2~3 个确认选项
- 计划表列名使用：日期、主题、训练内容；训练内容要像“脚底拉球 -> 内侧推球 -> 原地踩球”这样具体
- 流程节点按学习顺序输出，节点文字短而明确，方便界面渲染成彩色节点和箭头
- **每次只问一个问题**，只提供一组 options
- 对话文字要像和朋友聊天一样自然

### 禁止项
- 不要在 message 中包含技术标记（如 [TABLE_BEGIN]、[OPTIONS:] 等）
- 不要在 message 中使用步骤编号（"step1"、"步骤1"）
- 不要使用技术术语（"diagnose_goal"、"TaskFlow"等）
- 不要在 message 中使用 ### 或 ## 标题标记

### 完整对话范例

用户：我想学做饭

助手：
{"message": "好的，我来帮你规划学做饭的计划！\\n你目前对做饭了解多少呢？", "options": ["完全零基础", "会一点基础", "已经会几道菜"]}

用户：会一点基础

助手：
{"message": "明白了！那你每周大概能抽出多少时间来学呢？", "options": ["每天30分钟", "每天1小时", "每天2小时以上"]}

用户：每天1小时

助手：
{"message": "好的。学完之后你希望达到一个什么效果呢？", "options": ["学会几道家常菜", "掌握基本技巧", "能做一桌菜"]}

用户：学会几道家常菜

助手：
{"message": "太好了！根据你的情况，我建议你这样安排...\\n|阶段|任务|时间范围|说明|\\n|第1周|基础刀工练习|第1~7天|掌握切菜、切肉基本刀法|\\n|第2周|家常菜练习|第8~14天|学习炒菜、炖菜基础技巧|\\n|第3周|综合提升|第15~21天|尝试独立完成一餐|\\n  - 第1周：基础刀工练习\\n    - 学习正确的握刀姿势\\n  - 第2周：家常菜练习\\n    - 学习西红柿炒蛋、红烧肉\\n  - 第3周：综合提升\\n    - 独立完成三菜一汤\\n\\n这个计划你觉得怎么样？需要调整哪里吗？", "options": ["没问题继续", "需要调整一下", "换个方案"]}

## 规划对话流程（仅内部遵循）

1. 先简单确认你理解用户的目标（一句话即可）
2. 内心判断：当前水平、可用时间、截止日期、其他约束、偏好安排中哪些信息缺失
3. 从缺失信息中选最重要的一条，只问这一个问题，提供 options
4. 用户回答后，再问下一个问题，以此类推
5. 信息收集足够后，输出完整计划（Markdown 表格 + 缩进列表）
6. 最后问用户确认，提供 options

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

  Future<Map<String, dynamic>> chat({
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
        'temperature': 0.3,
        'max_tokens': 2048,
        'response_format': {'type': 'json_object'},
      },
    );

    final content = response.data['choices'][0]['message']['content'] as String;
    try {
      return json.decode(content) as Map<String, dynamic>;
    } catch (e) {
      // JSON 解析失败时，将原始内容作为 message 返回
      return {'message': content, 'options': <dynamic>[]};
    }
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
