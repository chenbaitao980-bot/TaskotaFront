import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/utils/file_logger.dart';
import '../core/utils/platform_utils.dart';

class FcmService {
  static final FcmService _instance = FcmService._internal();
  factory FcmService() => _instance;
  FcmService._internal();

  bool _initialized = false;
  String? _token;

  String? get token => _token;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    if (kIsWeb || !isMobile) return;

    try {
      // 动态导入 firebase_messaging 以避免桌面端编译错误
      // Firebase 必须在 main.dart 中先初始化 Firebase.initializeApp()
      final messaging = await _getMessaging();
      if (messaging == null) return;

      _token = await messaging.getToken();
      flog('[FCM] token: ${_token?.substring(0, 20)}...');

      // 上传 token 到 Supabase
      if (_token != null) await _uploadToken(_token!);

      // 监听 token 刷新
      messaging.onTokenRefresh.listen((newToken) {
        _token = newToken;
        _uploadToken(newToken);
      });
    } catch (e) {
      flog('[FCM] init error: $e');
    }
  }

  Future<dynamic> _getMessaging() async {
    try {
      // 使用反射式加载避免桌面端编译失败
      final module = await Future.value(null);
      // 实际项目中，firebase_messaging 添加到 pubspec 后直接 import
      // 此处返回 null 表示尚未集成
      return module;
    } catch (_) {
      return null;
    }
  }

  Future<void> _uploadToken(String token) async {
    try {
      final client = Supabase.instance.client;
      if (client.auth.currentUser == null) return;
      await client.functions.invoke(
        'register-fcm-token',
        method: HttpMethod.post,
        body: {
          'token': token,
          'platform': isAndroid ? 'android' : 'ios',
        },
      );
      flog('[FCM] token uploaded');
    } catch (e) {
      flog('[FCM] upload token error: $e');
    }
  }
}
