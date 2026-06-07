class AlarmService {
  static final AlarmService _instance = AlarmService._internal();
  factory AlarmService() => _instance;
  AlarmService._internal();

  static bool useNativeAlarm = true;

  Future<void> init() async {}

  Future<void> scheduleAlarm({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {}

  Future<void> cancelAlarm(int id) async {}
}
