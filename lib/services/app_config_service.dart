import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/utils/file_logger.dart';

/// 应用配置服务（Local-First 模式）
///
/// 从 Supabase `app_config` 表读取配置，支持：
/// - 网络优先拉取最新配置
/// - SharedPreferences 本地缓存兜底
/// - 硬编码默认值作为最后防线
///
/// 配置 key 命名规范：
/// - `help.common.{index}.{field}` — 帮助页"常用功能"
/// - `help.faq.{index}.{field}`     — 帮助页"常见问题"
/// - `help.feedback.{index}.{field}`— 帮助页"反馈方式"
/// - `about.core.{index}`           — 关于页"核心能力"
/// - `about.sync.{index}`           — 关于页"数据与同步"
/// - `about.privacy.{index}`        — 关于页"隐私与权限"
class AppConfigService {
  static final AppConfigService _instance = AppConfigService._();
  static AppConfigService get instance => _instance;
  AppConfigService._();

  final Map<String, String> _config = {};
  bool _isLoaded = false;

  bool get isLoaded => _isLoaded;

  /// 获取指定 key 的配置值
  String? get(String key) => _config[key];

  /// 获取所有配置（只读）
  Map<String, String> get allConfig => Map.unmodifiable(_config);

  static const _cacheKey = 'app_config_cache';
  static const _queryTimeout = Duration(seconds: 3);

  /// 初始化：先读缓存，后台刷新网络
  Future<void> init() async {
    await _loadFromCache();
    unawaited(refresh());
  }

  /// 从 Supabase 拉取最新配置，成功后写入缓存
  Future<void> refresh() async {
    try {
      final client = Supabase.instance.client;
      final response = await client
          .from('app_config')
          .select('key, value')
          .timeout(_queryTimeout);

      if (response is List) {
        _config.clear();
        for (final row in response) {
          final key = row['key'] as String;
          final value = row['value'] as String? ?? '';
          _config[key] = value;
        }
        _isLoaded = true;
        flog('[AppConfig] refreshed: ${_config.length} keys');
        await _saveToCache();
      }
    } catch (e) {
      flog('[AppConfig] refresh failed (will use cache/defaults): $e');
    }
  }

  // --- 本地缓存 ---

  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_cacheKey);
      if (json == null) return;

      final map = jsonDecode(json) as Map<String, dynamic>;
      _config.clear();
      map.forEach((k, v) => _config[k] = v.toString());
      _isLoaded = true;
      flog('[AppConfig] loaded from cache: ${_config.length} keys');
    } catch (e) {
      flog('[AppConfig] loadFromCache failed: $e');
    }
  }

  Future<void> _saveToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(_config));
    } catch (e) {
      flog('[AppConfig] saveToCache failed: $e');
    }
  }

  /// 清除缓存（登出时调用）
  void clearCache() {
    _config.clear();
    _isLoaded = false;
  }
}

// ============================================================
// 帮助与反馈页面 — 硬编码默认值（三级兜底）
// ============================================================

class HelpItemConfig {
  final String title;
  final String body;

  const HelpItemConfig({required this.title, required this.body});
}

class HelpSectionConfig {
  final String title;
  final List<HelpItemConfig> items;

  const HelpSectionConfig({required this.title, required this.items});
}

/// 帮助页默认内容（硬编码兜底）
const _kHelpFallbackSections = [
  HelpSectionConfig(title: '常用功能', items: [
    HelpItemConfig(title: '任务管理', body: '在任务页创建目标、项目和子任务，可用清单、附件和 Obsidian 链接补充任务资料。'),
    HelpItemConfig(title: 'AI 拆解', body: '在首页输入目标或任务描述，AI 会生成 WBS 子任务，并按工作时段尝试安排执行时间。'),
    HelpItemConfig(title: '日历提醒', body: '日历页展示日程和已排期任务；创建日程时可设置提前提醒和重复提醒。'),
    HelpItemConfig(title: '主题切换', body: '在我的页或设置页进入主题，选择暖珊瑚、极光蓝或曜石黑。'),
  ]),
  HelpSectionConfig(title: '常见问题', items: [
    HelpItemConfig(title: '为什么提醒没有响？', body: '请确认系统通知权限已开启；Android 还需要允许精确闹钟权限，桌面端需要应用保持运行。'),
    HelpItemConfig(title: '为什么多端数据不一致？', body: '云同步只在登录后启用。重新打开应用或切换登录状态后会进行一次全量对账。'),
    HelpItemConfig(title: '附件打不开怎么办？', body: '附件依赖本机文件路径或已同步的附件记录；如果源文件被移动或删除，需要重新添加。'),
  ]),
  HelpSectionConfig(title: '反馈方式', items: [
    HelpItemConfig(title: '问题反馈', body: '反馈时请附上操作步骤、发生页面、系统平台和截图，便于定位问题。'),
    HelpItemConfig(title: '功能建议', body: '可以描述你的使用场景、期望结果和当前绕路方式，后续会按影响面评估优先级。'),
  ]),
];

/// 从配置服务加载帮助页内容，缺失项回退到硬编码默认值
List<HelpSectionConfig> loadHelpContent() {
  final config = AppConfigService.instance;
  if (!config.isLoaded) return _kHelpFallbackSections;

  final sectionDefs = [
    {'prefix': 'help.common', 'title': '常用功能', 'count': 4},
    {'prefix': 'help.faq', 'title': '常见问题', 'count': 3},
    {'prefix': 'help.feedback', 'title': '反馈方式', 'count': 2},
  ];

  final List<HelpSectionConfig> sections = [];
  for (int si = 0; si < sectionDefs.length; si++) {
    final def = sectionDefs[si];
    final items = <HelpItemConfig>[];
    for (int i = 0; i < (def['count'] as int); i++) {
      final titleKey = '${def['prefix']}.$i.title';
      final bodyKey = '${def['prefix']}.$i.body';
      final title = config.get(titleKey);
      final body = config.get(bodyKey);
      if (title != null || body != null) {
        items.add(HelpItemConfig(
          title: title ?? '',
          body: body ?? '',
        ));
      }
    }
    if (items.isNotEmpty) {
      sections.add(HelpSectionConfig(title: def['title'] as String, items: items));
    }
  }

  // 如果有任何 section 为空，回退到默认值
  if (sections.isEmpty) return _kHelpFallbackSections;
  return sections;
}

// ============================================================
// 关于页面 — 硬编码默认值（三级兜底）
// ============================================================

class AboutSectionConfig {
  final String title;
  final List<String> items;

  const AboutSectionConfig({required this.title, required this.items});
}

/// 关于页默认内容（硬编码兜底）
const _kAboutFallbackSections = [
  AboutSectionConfig(title: '核心能力', items: [
    '把目标拆成可执行的任务、子任务和检查项。',
    '支持日历视图、任务排期、提醒和重复提醒。',
    '支持附件、Obsidian 链接、项目分组和多主题切换。',
  ]),
  AboutSectionConfig(title: '数据与同步', items: [
    '未登录时，任务和偏好设置主要保存在本机。',
    '登录后，任务、项目、检查项和附件元数据会通过 Supabase 同步。',
    '本地数据以设备应用数据目录为准，卸载或清理应用数据会影响本地记录。',
  ]),
  AboutSectionConfig(title: '隐私与权限', items: [
    '通知权限用于任务和日程提醒。',
    '文件访问只在用户主动选择或打开附件时使用。',
    'AI 拆解会处理用户主动提交的任务标题、描述和相关附件文本。',
  ]),
];

/// 从配置服务加载关于页内容，缺失项回退到硬编码默认值
List<AboutSectionConfig> loadAboutContent() {
  final config = AppConfigService.instance;
  if (!config.isLoaded) return _kAboutFallbackSections;

  final sectionDefs = [
    {'prefix': 'about.core', 'title': '核心能力', 'count': 3},
    {'prefix': 'about.sync', 'title': '数据与同步', 'count': 3},
    {'prefix': 'about.privacy', 'title': '隐私与权限', 'count': 3},
  ];

  final List<AboutSectionConfig> sections = [];
  for (final def in sectionDefs) {
    final items = <String>[];
    for (int i = 0; i < (def['count'] as int); i++) {
      final key = '${def['prefix']}.$i';
      final value = config.get(key);
      if (value != null && value.isNotEmpty) {
        items.add(value);
      }
    }
    if (items.isNotEmpty) {
      sections.add(AboutSectionConfig(title: def['title'] as String, items: items));
    }
  }

  // 如果有任何 section 为空，回退到默认值
  if (sections.isEmpty) return _kAboutFallbackSections;
  return sections;
}
