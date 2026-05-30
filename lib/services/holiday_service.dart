import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum HolidayType { statutory, makeupWork, traditional }

enum HolidayCountry {
  china('CN', '🇨🇳 中国'),
  usa('US', '🇺🇸 美国'),
  japan('JP', '🇯🇵 日本'),
  uk('GB', '🇬🇧 英国'),
  korea('KR', '🇰🇷 韩国');

  const HolidayCountry(this.code, this.label);
  final String code;
  final String label;
}

class HolidayInfo {
  const HolidayInfo({required this.name, required this.type});
  final String name;
  final HolidayType type;
}

class HolidayService {
  static final _dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 8)));
  static const _cacheTtlMs = 7 * 24 * 3600 * 1000; // 7 天

  static String _cacheKey(HolidayCountry country, int year) =>
      'holiday_cache_${country.name}_$year';

  /// 返回 key="yyyy-MM-dd" 的节假日 Map，优先读缓存
  static Future<Map<String, HolidayInfo>> fetchHolidays(
    HolidayCountry country,
    int year,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _cacheKey(country, year);
    final cached = prefs.getString(key);

    if (cached != null) {
      try {
        final json = jsonDecode(cached) as Map<String, dynamic>;
        final ts = json['ts'] as int;
        final fresh = DateTime.now().millisecondsSinceEpoch - ts < _cacheTtlMs;
        if (fresh) {
          return _deserialize(json['data'] as Map<String, dynamic>);
        }
        // 过期但先保留，网络失败时回退
      } catch (_) {}
    }

    try {
      final data = country == HolidayCountry.china
          ? await _fetchChina(year)
          : await _fetchNager(country, year);

      // 写缓存
      final payload = jsonEncode({
        'ts': DateTime.now().millisecondsSinceEpoch,
        'data': _serialize(data),
      });
      await prefs.setString(key, payload);
      return data;
    } catch (_) {
      // 网络失败 → 读过期缓存
      if (cached != null) {
        try {
          final json = jsonDecode(cached) as Map<String, dynamic>;
          return _deserialize(json['data'] as Map<String, dynamic>);
        } catch (_) {}
      }
      return {};
    }
  }

  static HolidayInfo? getHoliday(
    Map<String, HolidayInfo> holidays,
    DateTime date,
  ) {
    final key =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return holidays[key];
  }

  // ── 中国：timor.tools ──

  static Future<Map<String, HolidayInfo>> _fetchChina(int year) async {
    try {
      final res = await _dio.get('https://timor.tools/api/holiday/year/$year');
      final body = res.data is String ? jsonDecode(res.data as String) : res.data;
      final holiday = body['holiday'] as Map<String, dynamic>;
      final result = <String, HolidayInfo>{};
      for (final entry in holiday.entries) {
        final date = '$year-${entry.key}'; // entry.key 格式 "01-01"
        final info = entry.value as Map<String, dynamic>;
        final name = (info['name'] as String? ?? '').trim();
        final type = info['holiday'] == true
            ? HolidayType.statutory
            : HolidayType.makeupWork;
        if (name.isNotEmpty) {
          result[date] = HolidayInfo(name: name, type: type);
        }
      }
      if (result.isNotEmpty) return result;
      // timor 返回空 → 回退
      return await _fetchNager(HolidayCountry.china, year);
    } catch (_) {
      // timor 不可达 → 回退 nager（仅法定节假日，无调休补班）
      return await _fetchNager(HolidayCountry.china, year);
    }
  }

  // ── 其他国家：date.nager.at ──

  static Future<Map<String, HolidayInfo>> _fetchNager(
    HolidayCountry country,
    int year,
  ) async {
    final res = await _dio.get(
      'https://date.nager.at/api/v3/PublicHolidays/$year/${country.code}',
    );
    final list = res.data as List<dynamic>;
    final result = <String, HolidayInfo>{};
    for (final item in list) {
      final map = item as Map<String, dynamic>;
      final date = map['date'] as String;
      final name = (map['localName'] as String? ?? map['name'] as String? ?? '').trim();
      if (name.isNotEmpty) {
        result[date] = HolidayInfo(name: name, type: HolidayType.statutory);
      }
    }
    return result;
  }

  // ── 序列化 ──

  static Map<String, dynamic> _serialize(Map<String, HolidayInfo> data) {
    return data.map((k, v) => MapEntry(k, {'n': v.name, 't': v.type.index}));
  }

  static Map<String, HolidayInfo> _deserialize(Map<String, dynamic> raw) {
    return raw.map((k, v) {
      final m = v as Map<String, dynamic>;
      return MapEntry(
        k,
        HolidayInfo(
          name: m['n'] as String,
          type: HolidayType.values[m['t'] as int],
        ),
      );
    });
  }
}
