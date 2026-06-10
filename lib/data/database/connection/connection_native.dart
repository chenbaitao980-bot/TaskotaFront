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
    return NativeDatabase.createInBackground(file);
  });
}
