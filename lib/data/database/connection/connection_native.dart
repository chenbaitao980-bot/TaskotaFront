import 'package:drift/native.dart';
import 'package:drift/drift.dart';
import '../../../services/local_data_service.dart';

QueryExecutor openConnection() {
  return LazyDatabase(() async {
    final file = await LocalDataService().databaseFile();
    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }
    // 后台 isolate 执行 SQL，避免迁移/全表查询阻塞 UI isolate（W6）
    // 启用 WAL（prd 本地化性能方案）：drift 后台 isolate 写 + UI 读并发，
    // 减少 database is locked；synchronous=NORMAL 平衡持久性与性能。
    // Web 端不启用（Wasm 无文件 WAL，见 connection_web.dart）。
    return NativeDatabase.createInBackground(
      file,
      setup: (db) {
        db.execute('PRAGMA journal_mode=WAL;');
        db.execute('PRAGMA synchronous=NORMAL;');
      },
    );
  });
}
