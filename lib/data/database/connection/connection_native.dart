import 'package:drift/native.dart';
import 'package:drift/drift.dart';
import '../../../services/local_data_service.dart';

QueryExecutor openConnection() {
  return LazyDatabase(() async {
    final file = await LocalDataService().databaseFile();
    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }
    return NativeDatabase(file);
  });
}
