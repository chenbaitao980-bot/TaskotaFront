import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_assistant/services/local_data_service.dart';

void main() {
  test(
    'setDataDirectory copies database attachments and preferences',
    () async {
      final source = await Directory.systemTemp.createTemp('sa_local_source_');
      final target = await Directory.systemTemp.createTemp('sa_local_target_');
      addTearDown(() async {
        if (await source.exists()) await source.delete(recursive: true);
        if (await target.exists()) await target.delete(recursive: true);
      });

      await File(
        p.join(source.path, LocalDataService.databaseFileName),
      ).writeAsBytes([1, 2, 3], flush: true);
      final attachmentDir = Directory(
        p.join(
          source.path,
          LocalDataService.attachmentsDirectoryName,
          'task-1',
        ),
      );
      await attachmentDir.create(recursive: true);
      await File(p.join(attachmentDir.path, 'a.txt')).writeAsString('hello');

      SharedPreferences.setMockInitialValues({
        LocalDataService.dataDirectoryPrefKey: source.path,
        'user_profile': '{"name":"local"}',
        'excluded_project_ids': ['p1', 'p2'],
      });

      await LocalDataService().setDataDirectory(target.path);
      final prefs = await SharedPreferences.getInstance();
      final prefsFile = File(
        p.join(target.path, LocalDataService.preferencesFileName),
      );

      expect(
        await File(
          p.join(target.path, LocalDataService.databaseFileName),
        ).readAsBytes(),
        [1, 2, 3],
      );
      expect(
        await File(
          p.join(
            target.path,
            LocalDataService.attachmentsDirectoryName,
            'task-1',
            'a.txt',
          ),
        ).readAsString(),
        'hello',
      );
      expect(
        prefs.getString(LocalDataService.dataDirectoryPrefKey),
        target.path,
      );
      expect(await prefsFile.exists(), isTrue);
      expect(
        json.decode(await prefsFile.readAsString())['user_profile'],
        '{"name":"local"}',
      );
    },
  );

  test('backup can be imported into a fresh local data directory', () async {
    final source = await Directory.systemTemp.createTemp('sa_backup_source_');
    final target = await Directory.systemTemp.createTemp('sa_backup_target_');
    final backup = File(p.join(source.path, 'backup.zip'));
    addTearDown(() async {
      if (await source.exists()) await source.delete(recursive: true);
      if (await target.exists()) await target.delete(recursive: true);
    });

    await File(
      p.join(source.path, LocalDataService.databaseFileName),
    ).writeAsBytes([7, 8, 9], flush: true);
    SharedPreferences.setMockInitialValues({
      LocalDataService.dataDirectoryPrefKey: source.path,
      'user_profile': '{"name":"backup"}',
    });

    final service = LocalDataService();
    await service.writeBackup(backup);
    await service.importBackupToDirectory(backup.path, target.path);

    final prefs = await SharedPreferences.getInstance();
    expect(
      await File(
        p.join(target.path, LocalDataService.databaseFileName),
      ).readAsBytes(),
      [7, 8, 9],
    );
    expect(prefs.getString('user_profile'), '{"name":"backup"}');
    expect(prefs.getString(LocalDataService.dataDirectoryPrefKey), target.path);
  });
}
