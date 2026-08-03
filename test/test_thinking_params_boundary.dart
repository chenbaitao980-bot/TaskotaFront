// TestedSource: HomeLazyLogService._thinkingParams + HomeLazyLogService._omitTemperature + AssistantModelConfig@a4d8a7fd539d722f9a6ab66578c4e72e36f45fce
// Layer: DIRECT
//
// 边界补充: _thinkingParams 大小写/空白归一化 + _omitTemperature 推理模型变体
// 目的: 覆盖已有 home_lazy_log_service_test 未触及的输入空间（大小写混合、空白 effort、gpt-5/o3 变体）

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_assistant/models/assistant/assistant_models.dart';
import 'package:smart_assistant/services/home_lazy_log_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  group('_thinkingParams 大小写归一化', () {
    test('effort 大写 OFF 等价于 off（glm 发送 thinking disabled）', () async {
      final body = await _captureBody(
        config: const AssistantModelConfig(
          baseUrl: 'https://example.com',
          apiKey: 'key',
          model: 'glm-4.6',
          reasoningEffort: 'OFF',
        ),
      );
      expect(body['thinking'], {'type': 'disabled'});
    });

    test('effort 混合大小写 Low 发送 reasoning_effort low', () async {
      final body = await _captureBody(
        config: const AssistantModelConfig(
          baseUrl: 'https://example.com',
          apiKey: 'key',
          model: 'gpt-4o-mini',
          reasoningEffort: 'Low',
        ),
      );
      expect(body['reasoning_effort'], 'low');
    });

    test('effort 两侧空白被 trim 后仍生效', () async {
      final body = await _captureBody(
        config: const AssistantModelConfig(
          baseUrl: 'https://example.com',
          apiKey: 'key',
          model: 'qwen3-plus',
          reasoningEffort: ' off ',
        ),
      );
      expect(body['enable_thinking'], isFalse);
    });
  });

  group('_thinkingParams 空白/auto 边界', () {
    test('effort 仅空白 → 不发送任何思考参数', () async {
      final body = await _captureBody(
        config: const AssistantModelConfig(
          baseUrl: 'https://example.com',
          apiKey: 'key',
          model: 'glm-4.6',
          reasoningEffort: '   ',
        ),
      );
      expect(body.containsKey('thinking'), isFalse);
      expect(body.containsKey('enable_thinking'), isFalse);
      expect(body.containsKey('reasoning_effort'), isFalse);
    });
  });

  group('_omitTemperature OpenAI 推理模型变体', () {
    test('gpt-5 省略 temperature 并发送 reasoning_effort none（off）', () async {
      final body = await _captureBody(
        config: const AssistantModelConfig(
          baseUrl: 'https://example.com',
          apiKey: 'key',
          model: 'gpt-5',
          reasoningEffort: 'off',
        ),
      );
      expect(body.containsKey('temperature'), isFalse);
      expect(body['reasoning_effort'], 'none');
    });

    test('o3-mini 省略 temperature', () async {
      final body = await _captureBody(
        config: const AssistantModelConfig(
          baseUrl: 'https://example.com',
          apiKey: 'key',
          model: 'o3-mini',
          reasoningEffort: 'off',
        ),
      );
      expect(body.containsKey('temperature'), isFalse);
    });

    test('高 effort 对推理模型发送 reasoning_effort 且省略 temperature', () async {
      final body = await _captureBody(
        config: const AssistantModelConfig(
          baseUrl: 'https://example.com',
          apiKey: 'key',
          model: 'o1-preview',
          reasoningEffort: 'high',
        ),
      );
      expect(body.containsKey('temperature'), isFalse);
      expect(body['reasoning_effort'], 'high');
    });

    test('非推理模型保留 temperature（回归: 未误伤普通模型）', () async {
      final body = await _captureBody(
        config: const AssistantModelConfig(
          baseUrl: 'https://example.com',
          apiKey: 'key',
          model: 'qwen3-plus',
          reasoningEffort: 'low',
        ),
      );
      expect(body.containsKey('temperature'), isTrue);
    });
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
