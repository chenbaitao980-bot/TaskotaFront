import 'dart:convert';
import 'package:dio/dio.dart';
import '../core/constants/app_constants.dart';

/// A node in the subtask WBS tree.
class SubtaskNode {
  final String title;
  final List<SubtaskNode> children;

  const SubtaskNode(this.title, [this.children = const []]);

  factory SubtaskNode.fromJson(Map<String, dynamic> json) => SubtaskNode(
    (json['title'] as String?)?.trim() ?? '',
    (json['children'] as List<dynamic>?)
        ?.map((e) => SubtaskNode.fromJson(e as Map<String, dynamic>))
        .toList()
      ?? [],
  );
}

/// Result of a decomposition call.
class DecomposeResult {
  final List<SubtaskNode> nodes;
  /// True when AI returned results but all were filtered as duplicates.
  final bool allDuplicates;

  const DecomposeResult(this.nodes, {this.allDuplicates = false});

  bool get isEmpty => nodes.isEmpty;
}

/// Three-phase WBS decomposition service with dedup support.
class TaskDecompositionService {
  final Dio _dio;

  TaskDecompositionService()
      : _dio = Dio(BaseOptions(
          baseUrl: AppConstants.deepseekApiUrl,
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 60),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${AppConstants.deepseekApiKey}',
          },
        ));

  /// Decompose a task into a WBS tree.
  /// [existingTaskTitles] = already created subtask titles to avoid duplicates.
  Future<DecomposeResult> decompose(
    String title,
    String description,
    List<String> attachmentContents, {
    List<String> existingTaskTitles = const [],
  }) async {
    final descText = description.isNotEmpty ? description : title;
    final attachmentsText = attachmentContents.join('\n\n');

    try {
      final response = await _dio.post('', data: {
        'model': 'deepseek-chat',
        'messages': [
          {
            'role': 'system',
            'content': _systemPrompt(),
          },
          {
            'role': 'user',
            'content': _buildUserPrompt(title, descText, attachmentsText, existingTaskTitles),
          },
        ],
        'temperature': 0.1,
        'max_tokens': 4096,
      });

      final raw = _parseResponse(response.data);
      if (raw.isNotEmpty) {
        final deduped = _deduplicate(raw, existingTaskTitles);
        return DecomposeResult(deduped, allDuplicates: deduped.isEmpty && raw.isNotEmpty);
      }
    } catch (_) {}

    return DecomposeResult(_fallback(title, descText, existingTaskTitles));
  }

  String _systemPrompt() {
    return '''你是一个 WBS（工作分解结构）分解专家。你的任务是把用户的大任务拆成层级化的可执行子任务树。

核心原则：
1. **严格遵循描述的步骤顺序**：描述中先提到的步骤就是一级子任务
2. **按语义理解层级关系**：
   - "先做A，做完C和D再去做B" → A(一级)，B(一级，C和D是B的子任务)
   - "第1步X，第2步Y，第3步Z" → X、Y、Z 是平级一级子任务
   - "首先A，然后B，最后C" → A、B、C 是平级一级子任务
   - "做X，其中包括Y和Z" → X(一级，Y和Z是X的子任务)
3. **无明确步骤时**：按常识拆成 3-5 个逻辑阶段
4. **子任务标题用动词+名词**，具体可执行，保留描述中的原词
5. **最多 3 层深度**，每级 2-5 项
6. **禁止输出"已有子任务"列表中已经存在的任务**

只返回 JSON，格式：{"subtasks":[{"title":"动词+名词","children":[{"title":"子任务","children":[]}]}]}''';
  }

  String _buildUserPrompt(
    String title,
    String description,
    String attachments,
    List<String> existingTaskTitles,
  ) {
    final buf = StringBuffer();
    // Content hash + timestamp to bust any prompt caching
    final contentSeed = '${title.hashCode}_${description.hashCode}_${DateTime.now().millisecondsSinceEpoch}';
    buf.writeln('## 请求标识 (忽略此字段，仅用于刷新)');
    buf.writeln(contentSeed);
    buf.writeln('');

    buf.writeln('## 任务标题');
    buf.writeln(title);
    buf.writeln('');

    buf.writeln('## 任务描述');
    buf.writeln(description);

    if (attachments.isNotEmpty) {
      buf.writeln('');
      buf.writeln('## 参考资料');
      buf.writeln(attachments.length > 4000
          ? attachments.substring(0, 4000)
          : attachments);
    }

    if (existingTaskTitles.isNotEmpty) {
      buf.writeln('');
      buf.writeln('## 已有子任务（请不要重复创建这些任务）');
      for (final t in existingTaskTitles) {
        buf.writeln('- $t');
      }
    }

    return buf.toString();
  }

  List<SubtaskNode> _parseResponse(dynamic responseData) {
    try {
      final content = responseData?['choices']?[0]?['message']?['content'] as String?;
      if (content == null || content.isEmpty) return [];

      var jsonStr = content.trim();

      // Strip markdown code block markers
      if (jsonStr.contains('```')) {
        jsonStr = jsonStr.replaceAll(RegExp(r'```[a-z]*\n?'), '').trim();
      }

      // Find the first { and last } to extract the JSON object
      final firstBrace = jsonStr.indexOf('{');
      final lastBrace = jsonStr.lastIndexOf('}');
      if (firstBrace < 0 || lastBrace <= firstBrace) return [];
      jsonStr = jsonStr.substring(firstBrace, lastBrace + 1);

      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      final subtasks = json['subtasks'] as List<dynamic>?;
      if (subtasks == null || subtasks.isEmpty) return [];

      return subtasks
          .map((e) => SubtaskNode.fromJson(e as Map<String, dynamic>))
          .where((n) => n.title.isNotEmpty && !_isJunkTitle(n.title))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Remove nodes whose titles already exist (exact + fuzzy match).
  List<SubtaskNode> _deduplicate(List<SubtaskNode> nodes, List<String> existingTitles) {
    if (existingTitles.isEmpty) return nodes;

    final existingTrimmed = existingTitles.map((t) => t.trim()).toList();

    bool isDuplicate(String title) {
      final t = title.trim();
      if (t.isEmpty) return true;
      // 1) Exact match
      if (existingTrimmed.contains(t)) return true;
      // 2) Character n-gram fuzzy match (Jaccard ≥ 0.45)
      for (final existing in existingTrimmed) {
        if (_charSimilarity(t, existing) >= 0.45) return true;
      }
      return false;
    }

    return nodes.where((n) => !isDuplicate(n.title)).map((n) {
      if (n.children.isEmpty) return n;
      return SubtaskNode(n.title, _deduplicate(n.children, existingTitles));
    }).toList();
  }

  /// Chinese character bigram Jaccard similarity.
  double _charSimilarity(String a, String b) {
    if (a.isEmpty && b.isEmpty) return 1.0;
    if (a.isEmpty || b.isEmpty) return 0.0;

    // If one contains the other fully, it's a match
    if (a.contains(b) || b.contains(a)) return 1.0;

    // Build character bigrams
    Set<String> bigrams(String s) {
      final result = <String>{};
      for (var i = 0; i < s.length - 1; i++) {
        result.add(s.substring(i, i + 2));
      }
      // Also add single characters for short strings
      if (s.length <= 3) {
        for (var i = 0; i < s.length; i++) {
          result.add(s[i]);
        }
      }
      return result;
    }

    final setA = bigrams(a);
    final setB = bigrams(b);

    final intersection = setA.intersection(setB).length;
    final union = setA.union(setB).length;
    return union == 0 ? 0.0 : intersection / union;
  }

  bool _isJunkTitle(String title) {
    final junk = ['测试', 'test', '示例', 'example', '待办', 'todo', 'fixme'];
    return title.length < 2 || junk.any((j) => title.contains(j));
  }

  List<SubtaskNode> _fallback(String title, String description, List<String> existingTitles) {
    final combined = '$title $description';

    List<SubtaskNode> generate(List<SubtaskNode> candidates) {
      final result = candidates.where((n) =>
          !existingTitles.contains(n.title.trim())
      ).toList();
      return result.isNotEmpty ? result : [SubtaskNode('$title（细化）')];
    }

    if (_hasAny(combined, ['日语', 'N1', '考试', '复习', '学习', '备考', '语言', '留学'])) {
      return generate([
        const SubtaskNode('报名考试'),
        const SubtaskNode('收集学习资料与制定计划'),
        const SubtaskNode('分模块系统学习'),
        const SubtaskNode('真题练习与模拟考试'),
        const SubtaskNode('查漏补缺与冲刺'),
      ]);
    }

    if (_hasAny(combined, ['发布', '上线', '推广', '营销', '宣传', '发行'])) {
      return generate([
        const SubtaskNode('制定发布计划'),
        const SubtaskNode('准备发布物料'),
        const SubtaskNode('渠道部署与配置'),
        const SubtaskNode('上线检查与监控'),
        const SubtaskNode('发布后跟进与优化'),
      ]);
    }

    if (_hasAny(combined, ['研究', '调研', '分析', '调查', '评估', '方案'])) {
      return generate([
        const SubtaskNode('明确研究目标与范围'),
        const SubtaskNode('收集相关资料与数据'),
        const SubtaskNode('整理与分析信息'),
        const SubtaskNode('输出分析报告'),
        const SubtaskNode('方案评审与修订'),
      ]);
    }

    if (_hasAny(combined, ['开发', '实现', '编码', '编程', '写代码', '创建', '构建'])) {
      return generate([
        const SubtaskNode('需求分析与技术方案设计'),
        const SubtaskNode('环境搭建与框架配置'),
        const SubtaskNode('核心功能编码实现'),
        const SubtaskNode('测试验证与Bug修复'),
        const SubtaskNode('部署上线与文档整理'),
      ]);
    }

    final steps = _extractSteps(description);
    if (steps.length >= 2) {
      return steps
          .map((s) => SubtaskNode(s))
          .where((n) => !existingTitles.contains(n.title.trim()))
          .toList();
    }

    return [SubtaskNode(title)];
  }

  bool _hasAny(String text, List<String> keywords) {
    return keywords.any((k) => text.contains(k));
  }

  List<String> _extractSteps(String text) {
    if (text.isEmpty) return [];

    final parts = text.split(RegExp(r'[；;。.！!？?\n]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty && s.length > 2)
        .toList();

    if (parts.length >= 3 && parts.length <= 8) return parts;

    final numbered = RegExp(r'(?:^|[，,。\n])\s*(\d+[.、)\s]\s*[^，,。\n]{3,})');
    final matches = numbered.allMatches(text).toList();
    if (matches.length >= 2) {
      return matches
          .map((m) => m.group(1)!.replaceFirst(RegExp(r'^\d+[.、)\s]\s*'), '').trim())
          .where((s) => s.length > 2)
          .toList();
    }

    return [];
  }
}
