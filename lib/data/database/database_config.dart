import 'package:drift/native.dart';

class DatabaseConfig {
  /// 数据库文件名
  static const String dbFileName = 'smart_assistant.db';

  /// 数据库版本
  static const int dbVersion = 1;

  /// 删除数据库（用户数据会丢失，仅用于调试）
  static void deleteDatabase(NativeDatabase db) {
    db.close();
  }
}
