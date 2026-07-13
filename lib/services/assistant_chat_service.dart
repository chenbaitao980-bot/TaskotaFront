import 'dart:convert';

import 'package:dio/dio.dart';

import '../models/assistant/assistant_models.dart';
import 'assistant_tool_service.dart';

class AssistantChatResult {
  final List<AssistantMessage> messagesToAppend;

  const AssistantChatResult(this.messagesToAppend);
}

class AssistantChatService {
  final Dio _dio;
  final AssistantToolService toolService;

  AssistantChatService({required this.toolService, Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 30),
              receiveTimeout: const Duration(seconds: 90),
            ),
          );

  Future<AssistantChatResult> send({
    required AssistantModelConfig config,
    required List<AssistantMessage> history,
    required String question,
  }) async {
    if (!config.isComplete) {
      return AssistantChatResult([
        AssistantMessage(
          role: 'assistant',
          content: '请先配置模型 API 后再开始对话。',
          createdAt: DateTime.now(),
        ),
      ]);
    }

    final apiMessages = <Map<String, dynamic>>[
      {'role': 'system', 'content': _systemPrompt(config.userInstructions)},
      ..._historyForApi(history),
      {'role': 'user', 'content': question},
    ];
    final visibleMessages = <AssistantMessage>[];
    final allSources = <AssistantSource>[];

    for (var turn = 0; turn < 6; turn++) {
      final message = await _request(config, apiMessages);
      final content = (message['content'] as String? ?? '').trim();
      final reasoning = _reasoningFrom(message);
      final toolCalls = _toolCallsFrom(message);

      if (toolCalls.isEmpty) {
        visibleMessages.add(
          AssistantMessage(
            role: 'assistant',
            content: content.isEmpty ? '我没有拿到可用回答。' : content,
            reasoningContent: reasoning,
            createdAt: DateTime.now(),
            sources: allSources,
          ),
        );
        return AssistantChatResult(visibleMessages);
      }

      apiMessages.add({
        'role': 'assistant',
        'content': content.isEmpty ? null : content,
        'tool_calls': toolCalls
            .map(
              (call) => {
                'id': call.id,
                'type': 'function',
                'function': {'name': call.name, 'arguments': call.arguments},
              },
            )
            .toList(),
      });
      visibleMessages.add(
        AssistantMessage(
          role: 'assistant',
          content: content,
          reasoningContent: reasoning,
          createdAt: DateTime.now(),
          toolCalls: toolCalls,
        ),
      );

      for (final call in toolCalls) {
        final execution = await toolService.execute(
          toolName: call.name,
          arguments: decodeAssistantJsonObject(call.arguments),
        );
        allSources.addAll(execution.sources);
        apiMessages.add({
          'role': 'tool',
          'tool_call_id': call.id,
          'content': execution.content,
        });
        visibleMessages.add(
          AssistantMessage(
            role: 'tool',
            content: execution.content,
            createdAt: DateTime.now(),
            toolName: execution.toolName,
            toolCallId: call.id,
            sources: execution.sources,
          ),
        );
      }
    }

    visibleMessages.add(
      AssistantMessage(
        role: 'assistant',
        content: '工具调用轮次已达到上限，请把问题缩小到具体日期、项目名或关键词后再试。',
        createdAt: DateTime.now(),
        sources: allSources,
      ),
    );
    return AssistantChatResult(visibleMessages);
  }

  Future<Map<String, dynamic>> _request(
    AssistantModelConfig config,
    List<Map<String, dynamic>> messages,
  ) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        config.endpoint,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${config.apiKey.trim()}',
          },
        ),
        data: {
          'model': config.model.trim(),
          'messages': messages,
          'tools': AssistantToolService.toolSchemas,
          'tool_choice': 'auto',
          'temperature': 0.2,
        },
      );
      final choices = response.data?['choices'] as List<dynamic>?;
      final first = choices?.isNotEmpty == true ? choices!.first : null;
      final message = first is Map<String, dynamic>
          ? first['message'] as Map<String, dynamic>?
          : null;
      if (message == null) {
        return {'content': '模型返回格式不可识别。'};
      }
      return message;
    } on DioException catch (e) {
      final data = e.response?.data;
      final detail = data is Map ? jsonEncode(data) : (data?.toString() ?? '');
      return {
        'content':
            '模型请求失败：${e.message ?? e.type.name}${detail.isEmpty ? '' : '\n\n$detail'}',
      };
    } catch (e) {
      return {'content': '模型请求失败：$e'};
    }
  }

  List<Map<String, dynamic>> _historyForApi(List<AssistantMessage> history) {
    final visible = history
        .where((message) => message.role == 'user' || message.isAssistant)
        .where((message) => message.content.trim().isNotEmpty)
        .toList();
    final trimmed = visible.length <= 16
        ? visible
        : visible.sublist(visible.length - 16);
    return trimmed
        .map(
          (message) => {
            'role': message.role == 'user' ? 'user' : 'assistant',
            'content': message.content,
          },
        )
        .toList();
  }

  List<AssistantToolCall> _toolCallsFrom(Map<String, dynamic> message) {
    final raw = message['tool_calls'] as List<dynamic>?;
    if (raw == null) return [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map((item) {
          final fn = item['function'] as Map<String, dynamic>? ?? const {};
          return AssistantToolCall(
            id: item['id'] as String? ?? '',
            name: fn['name'] as String? ?? '',
            arguments: fn['arguments'] as String? ?? '{}',
          );
        })
        .where((call) => call.id.isNotEmpty && call.name.isNotEmpty)
        .toList();
  }

  String _reasoningFrom(Map<String, dynamic> message) {
    final value =
        message['reasoning_content'] ??
        message['reasoning'] ??
        message['thinking'];
    return value is String ? value.trim() : '';
  }

  String _systemPrompt(String userInstructions) {
    final preferences = _userInstructionsBlock(userInstructions);
    return '''
你是 Taskora 的只读任务助手。你可以通过工具检索本机任务、项目和日历日程，然后用中文回答用户。

规则：
1. 第一版只读：不要承诺创建、修改、删除任务/项目/日程。用户要求写入时，说明当前版本只支持查看与总结。
2. 涉及今天、本周、某项目、某时间段时，优先调用工具获取本机数据。
3. 回答要引用你查到的事实，必要时用 Markdown 列表或表格。
4. 如果工具结果为空，明确说明没有找到匹配记录，并建议更具体的关键词或日期。
$preferences
''';
  }

  String _userInstructionsBlock(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';
    return '''

用户自定义 CLAUDE.md 偏好：
$trimmed
请在不违反上方规则的前提下遵循这些偏好。''';
  }
}
