import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';

import '../../../core/utils/file_logger.dart';

QueryExecutor openConnection() {
  return LazyDatabase(() async {
    final result = await WasmDatabase.open(
      databaseName: 'smart_assistant',
      sqlite3Uri: Uri.parse('sqlite3.wasm'),
      driftWorkerUri: Uri.parse('drift_worker.dart.js'),
    );

    if (result.missingFeatures.isNotEmpty) {
      flog('[DriftWeb] degraded mode: ${result.missingFeatures}');
    }

    return result.resolvedExecutor;
  });
}
