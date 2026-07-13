import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/assistant/assistant_models.dart';

class AssistantConfigService {
  static const _configKey = 'assistant_model_config';
  static const _messagesKey = 'assistant_conversation_messages';
  static const int _maxPersistedMessages = 80;

  Future<AssistantModelConfig> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_configKey);
    if (raw == null || raw.isEmpty) return const AssistantModelConfig();
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return AssistantModelConfig.fromJson(decoded);
    } catch (_) {
      return const AssistantModelConfig();
    }
  }

  Future<void> saveConfig(AssistantModelConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_configKey, jsonEncode(config.toJson()));
  }

  Future<List<AssistantMessage>> loadMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_messagesKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(AssistantMessage.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveMessages(List<AssistantMessage> messages) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = messages.length <= _maxPersistedMessages
        ? messages
        : messages.sublist(messages.length - _maxPersistedMessages);
    await prefs.setString(
      _messagesKey,
      jsonEncode(trimmed.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> clearMessages() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_messagesKey);
  }
}
