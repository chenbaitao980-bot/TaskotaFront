import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_assistant/data/database/app_database.dart';
import 'package:smart_assistant/services/local_data_service.dart';
import 'package:smart_assistant/services/task_attachment_service.dart';

void main() {
  test('saveImageBytes stores pasted image bytes as an attachment', () async {
    final dataDir = await Directory.systemTemp.createTemp('sa_attach_bytes_');
    addTearDown(() async {
      if (await dataDir.exists()) await dataDir.delete(recursive: true);
    });
    SharedPreferences.setMockInitialValues({
      LocalDataService.dataDirectoryPrefKey: dataDir.path,
    });

    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final service = TaskAttachmentService()..bind(database);

    final attachment = await service.saveImageBytes(
      'task-1',
      fileName: 'clipboard.png',
      bytes: Uint8List.fromList([1, 2, 3, 4]),
    );
    final rows = await service.getAttachments('task-1');

    expect(rows, hasLength(1));
    expect(rows.single.id, attachment.id);
    expect(rows.single.isImage, isTrue);
    expect(rows.single.mimeType, 'image/png');
    expect(
      await File(
        p.join(
          dataDir.path,
          LocalDataService.attachmentsDirectoryName,
          'task-1',
          '${attachment.id}_clipboard.png',
        ),
      ).readAsBytes(),
      [1, 2, 3, 4],
    );
  });
}
