import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_assistant/models/assistant/assistant_models.dart';
import 'package:smart_assistant/models/assistant/lazy_log_models.dart';
import 'package:smart_assistant/services/home_lazy_log_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  test(
    'falls back to local structuring when model config is incomplete',
    () async {
      final result = await HomeLazyLogService().structure(
        config: const AssistantModelConfig(),
        input: '今天完成首页懒人日志；遇到模型配置问题；明天准备联调日程创建',
      );

      expect(result.usedFallback, isTrue);
      expect(result.completed, contains('今天完成首页懒人日志'));
      expect(result.blockers, contains('遇到模型配置问题'));
      expect(result.nextActions, contains('明天准备联调日程创建'));
      expect(result.tasks.single.title, contains('联调日程创建'));
    },
  );

  test('parses structured task and schedule drafts', () {
    final result = LazyLogResult.fromJson({
      'summary': '整理今日输入',
      'completed': ['完成输入面板'],
      'blockers': ['无'],
      'nextActions': ['联调'],
      'parentTitle': 'SRM相关内容',
      'projectGroupHint': '生活',
      'projectHint': '杂事',
      'tasks': [
        {
          'title': '修复首页样式',
          'description': '检查移动端布局',
          'priority': 'P1',
          'checklist': ['验证桌面端', '验证移动端'],
          'dueTime': '2026-07-14T18:00:00',
        },
      ],
      'schedules': [
        {
          'title': '项目复盘',
          'priority': 'P2',
          'startTime': '2026-07-14T10:00:00',
          'endTime': '2026-07-14T11:00:00',
        },
      ],
    });

    expect(result.summary, '整理今日输入');
    expect(result.parentTitle, 'SRM相关内容');
    expect(result.projectGroupHint, '生活');
    expect(result.projectHint, '杂事');
    expect(result.tasks.single.priority, 'P1');
    expect(result.tasks.single.checklist, ['验证桌面端', '验证移动端']);
    expect(result.tasks.single.dueTime?.hour, 18);
    expect(result.schedules.single.title, '项目复盘');
    expect(result.schedules.single.endTime.hour, 11);
  });

  test('normalizes current-week task deadline into a week range', () async {
    String? capturedSystemPrompt;
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            final data = options.data as Map<String, dynamic>;
            final messages = data['messages'] as List<dynamic>;
            capturedSystemPrompt =
                (messages.first as Map<String, dynamic>)['content'] as String?;
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                data: {
                  'choices': [
                    {
                      'message': {
                        'content': jsonEncode({
                          'summary': '安排本周方案',
                          'tasks': [
                            {
                              'title': '让甄云供应商完成方案',
                              'priority': 'P2',
                              'startTime': '2026-07-19T22:59:00',
                              'dueTime': '2026-07-19T23:59:00',
                            },
                          ],
                          'schedules': [],
                        }),
                      },
                    },
                  ],
                },
              ),
            );
          },
        ),
      );

    final result = await HomeLazyLogService(dio: dio).structure(
      config: const AssistantModelConfig(
        baseUrl: 'https://example.com',
        apiKey: 'key',
        model: 'model',
        userInstructions: 'WEEK_RANGE_RULE',
      ),
      input: '这周让甄云供应商完成方案',
      projectRoutingContext: '- 分组：生活\n  - 项目：杂事',
      now: DateTime(2026, 7, 13, 10),
    );

    final task = result.tasks.single;
    expect(capturedSystemPrompt, contains('WEEK_RANGE_RULE'));
    expect(capturedSystemPrompt, contains('项目：杂事'));
    expect(task.startTime, DateTime(2026, 7, 13, 9));
    expect(task.dueTime, DateTime(2026, 7, 19, 18));
  });

  test(
    'instructs model to keep checklist grounded in explicit log items',
    () async {
      String? capturedSystemPrompt;
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              final data = options.data as Map<String, dynamic>;
              final messages = data['messages'] as List<dynamic>;
              capturedSystemPrompt =
                  (messages.first as Map<String, dynamic>)['content']
                      as String?;
              handler.resolve(
                Response<Map<String, dynamic>>(
                  requestOptions: options,
                  data: {
                    'choices': [
                      {
                        'message': {
                          'content': jsonEncode({
                            'summary': '安排懒人日志优化',
                            'tasks': [
                              {
                                'title': '优化懒人日志检查项',
                                'description': '不要生成日志没有写的检查项',
                                'priority': 'P2',
                                'checklist': [],
                              },
                            ],
                            'schedules': [],
                          }),
                        },
                      },
                    ],
                  },
                ),
              );
            },
          ),
        );

      final result = await HomeLazyLogService(dio: dio).structure(
        config: const AssistantModelConfig(
          baseUrl: 'https://example.com',
          apiKey: 'key',
          model: 'model',
        ),
        input: '懒人日志检查项太发散，没有写就不要生成',
        now: DateTime(2026, 7, 15, 10),
      );

      expect(result.tasks.single.checklist, isEmpty);
      expect(capturedSystemPrompt, contains('只有用户原文明确列出步骤、验收点或待检查事项时才填写'));
      expect(capturedSystemPrompt, contains('不要因为任务看起来复杂就自行拆解、补充或推断检查点'));
      expect(capturedSystemPrompt, isNot(contains('任务步骤比较多、验收点明确或执行较复杂')));
    },
  );

  test('persists assistant CLAUDE.md preferences in model config json', () {
    const config = AssistantModelConfig(
      baseUrl: 'https://example.com',
      apiKey: 'key',
      model: 'model',
      userInstructions: 'Prefer week ranges for current-week tasks.',
    );

    final restored = AssistantModelConfig.fromJson(config.toJson());

    expect(
      restored.userInstructions,
      'Prefer week ranges for current-week tasks.',
    );
  });

  test('persists reasoningEffort in model config json and defaults to auto', () {
    const config = AssistantModelConfig(
      baseUrl: 'https://example.com',
      apiKey: 'key',
      model: 'model',
      reasoningEffort: 'off',
    );

    final restored = AssistantModelConfig.fromJson(config.toJson());
    expect(restored.reasoningEffort, 'off');

    // 旧版本持久化 JSON 没有该字段 → 默认 'auto'
    final legacy = AssistantModelConfig.fromJson({'baseUrl': 'x'});
    expect(legacy.reasoningEffort, 'auto');
  });

  test('off thinking for glm sends thinking disabled', () async {
    final body = await _captureBody(
      config: const AssistantModelConfig(
        baseUrl: 'https://example.com',
        apiKey: 'key',
        model: 'glm-4.6',
        reasoningEffort: 'off',
      ),
    );
    expect(body['thinking'], {'type': 'disabled'});
    expect(body.containsKey('temperature'), isTrue);
  });

  test('off thinking for deepseek sends thinking disabled', () async {
    final body = await _captureBody(
      config: const AssistantModelConfig(
        baseUrl: 'https://example.com',
        apiKey: 'key',
        model: 'deepseek-v4-flash',
        reasoningEffort: 'off',
      ),
    );
    expect(body['thinking'], {'type': 'disabled'});
  });

  test('off thinking for qwen sends enable_thinking false', () async {
    final body = await _captureBody(
      config: const AssistantModelConfig(
        baseUrl: 'https://example.com',
        apiKey: 'key',
        model: 'qwen3-plus',
        reasoningEffort: 'off',
      ),
    );
    expect(body['enable_thinking'], isFalse);
  });

  test('off thinking for kimi sends reasoning_effort low', () async {
    final body = await _captureBody(
      config: const AssistantModelConfig(
        baseUrl: 'https://example.com',
        apiKey: 'key',
        model: 'kimi-k3',
        reasoningEffort: 'off',
      ),
    );
    expect(body['reasoning_effort'], 'low');
  });

  test('off thinking for openai reasoning model omits temperature', () async {
    final body = await _captureBody(
      config: const AssistantModelConfig(
        baseUrl: 'https://example.com',
        apiKey: 'key',
        model: 'o1-mini',
        reasoningEffort: 'off',
      ),
    );
    expect(body['reasoning_effort'], 'none');
    expect(body.containsKey('temperature'), isFalse);
  });

  test('off thinking falls back to reasoning_effort low for unknown model',
      () async {
    final body = await _captureBody(
      config: const AssistantModelConfig(
        baseUrl: 'https://example.com',
        apiKey: 'key',
        model: 'unknown-xyz',
        reasoningEffort: 'off',
      ),
    );
    expect(body['reasoning_effort'], 'low');
  });

  test('low effort sends reasoning_effort low and keeps temperature', () async {
    final body = await _captureBody(
      config: const AssistantModelConfig(
        baseUrl: 'https://example.com',
        apiKey: 'key',
        model: 'gpt-4o-mini',
        reasoningEffort: 'low',
      ),
    );
    expect(body['reasoning_effort'], 'low');
    expect(body.containsKey('temperature'), isTrue);
  });

  test('auto effort sends no thinking params but keeps temperature', () async {
    final body = await _captureBody(
      config: const AssistantModelConfig(
        baseUrl: 'https://example.com',
        apiKey: 'key',
        model: 'gpt-4o-mini',
      ),
    );
    expect(body.containsKey('thinking'), isFalse);
    expect(body.containsKey('enable_thinking'), isFalse);
    expect(body.containsKey('reasoning_effort'), isFalse);
    expect(body.containsKey('temperature'), isTrue);
  });
}

Future<Map<String, dynamic>> _captureBody({
  required AssistantModelConfig config,
  String input = '今天完成首页懒人日志',
}) async {
  late Map<String, dynamic> captured;
  final dio = Dio()
    ..interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          captured = options.data as Map<String, dynamic>;
          handler.resolve(
            Response<Map<String, dynamic>>(
              requestOptions: options,
              data: {
                'choices': [
                  {
                    'message': {
                      'content': jsonEncode({
                        'summary': '测试',
                        'tasks': <dynamic>[],
                        'schedules': <dynamic>[],
                      }),
                    },
                  },
                ],
              },
            ),
          );
        },
      ),
    );
  await HomeLazyLogService(dio: dio).structure(
    config: config,
    input: input,
    now: DateTime(2026, 7, 15, 10),
  );
  return captured;
}
