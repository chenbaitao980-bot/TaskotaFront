import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/assistant/lazy_log_mapping.dart';

class LazyLogMappingService {
  static const _key = 'lazy_log_keyword_mappings';

  Future<List<LazyLogKeywordMapping>> loadMappings() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_key);
    if (jsonStr == null || jsonStr.isEmpty) return _defaultMappings();
    try {
      final list = json.decode(jsonStr) as List;
      return list
          .map((e) => LazyLogKeywordMapping.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return _defaultMappings();
    }
  }

  Future<void> saveMappings(List<LazyLogKeywordMapping> mappings) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = json.encode(mappings.map((m) => m.toJson()).toList());
    await prefs.setString(_key, jsonStr);
  }

  Future<void> addMapping(LazyLogKeywordMapping mapping) async {
    final mappings = await loadMappings();
    mappings.add(mapping);
    await saveMappings(mappings);
  }

  Future<void> updateMapping(LazyLogKeywordMapping updated) async {
    final mappings = await loadMappings();
    final index = mappings.indexWhere((m) => m.id == updated.id);
    if (index == -1) return;
    mappings[index] = updated;
    await saveMappings(mappings);
  }

  Future<void> deleteMapping(String id) async {
    final mappings = await loadMappings();
    mappings.removeWhere((m) => m.id == id);
    await saveMappings(mappings);
  }

  Future<void> toggleMapping(String id, bool enabled) async {
    final mappings = await loadMappings();
    final index = mappings.indexWhere((m) => m.id == id);
    if (index == -1) return;
    mappings[index] = mappings[index].copyWith(enabled: enabled);
    await saveMappings(mappings);
  }

  /// 所有启用的时间映射（有 afterHour）
  Future<List<LazyLogKeywordMapping>> loadTimeMappings() async {
    final all = await loadMappings();
    return all.where((m) => m.enabled && m.afterHour != null).toList();
  }

  /// 所有启用的项目映射（有 projectId）
  Future<List<LazyLogKeywordMapping>> loadProjectMappings() async {
    final all = await loadMappings();
    return all
        .where(
          (m) => m.enabled && m.projectId != null && m.projectId!.isNotEmpty,
        )
        .toList();
  }

  List<LazyLogKeywordMapping> _defaultMappings() {
    return [
      LazyLogKeywordMapping.create(
        triggers: ['下班', '放工', '收工'],
        afterHour: 17,
        afterMinute: 0,
      ),
      LazyLogKeywordMapping.create(
        triggers: ['午休', '中午休息'],
        afterHour: 12,
        afterMinute: 0,
      ),
    ];
  }
}
