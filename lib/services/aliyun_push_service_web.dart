class AliyunPushService {
  static final AliyunPushService _instance = AliyunPushService._internal();
  factory AliyunPushService() => _instance;
  AliyunPushService._internal();

  Future<void> init() async {}

  Future<void> onUserLoggedIn() async {}
}
