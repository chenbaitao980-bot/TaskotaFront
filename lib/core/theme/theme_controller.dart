import 'package:flutter/material.dart';
import '../../services/local_storage_service.dart';
import 'app_theme.dart';

/// 主题控制器：持有当前主题、持久化、并在切换时通知 MaterialApp 重建。
class ThemeController extends ChangeNotifier {
  final LocalStorageService _storage = LocalStorageService();

  AppThemeId _current = AppThemeId.claude;
  AppThemeId get current => _current;

  /// 启动时加载持久化的主题；在 runApp 前调用。
  Future<void> load() async {
    await _storage.init();
    final saved = _storage.themeId;
    if (saved != null) {
      _current = AppThemeId.values.firstWhere(
        (e) => e.name == saved,
        orElse: () => AppThemeId.claude,
      );
    }
    AppTheme.setPalette(_current);
  }

  /// 切换主题：应用 + 持久化 + 通知重建。
  Future<void> setTheme(AppThemeId id) async {
    if (id == _current) return;
    _current = id;
    AppTheme.setPalette(id);
    await _storage.setThemeId(id.name);
    notifyListeners();
  }
}

/// 全局单例，供 MaterialApp 与设置页共享。
final ThemeController themeController = ThemeController();
