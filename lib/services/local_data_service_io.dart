import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalDataService {
  static const dataDirectoryPrefKey = 'local_data_directory';
  static const databaseFileName = 'smart_assistant.db';
  static const attachmentsDirectoryName = 'task_attachments';
  static const preferencesFileName = 'preferences.json';

  bool get isDesktop =>
      Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  Future<String?> configuredDataDirectory() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(dataDirectoryPrefKey);
    if (value == null || value.trim().isEmpty) return null;
    return value;
  }

  Future<String> activeDataDirectoryPath() async {
    final configured = await configuredDataDirectory();
    if (configured != null) return configured;
    return (await getApplicationDocumentsDirectory()).path;
  }

  Future<File> databaseFile() async {
    final dir = await activeDataDirectoryPath();
    return File(p.join(dir, databaseFileName));
  }

  Future<Directory> attachmentsDirectory() async {
    final dir = Directory(
      p.join(await activeDataDirectoryPath(), attachmentsDirectoryName),
    );
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<String?> pickDataDirectory() {
    return FilePicker.platform.getDirectoryPath(
      dialogTitle: '选择本地数据保存位置',
      lockParentWindow: true,
    );
  }

  Future<String?> pickBackupFile() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: '选择本地数据备份',
      type: FileType.custom,
      allowedExtensions: const ['zip'],
      allowMultiple: false,
      lockParentWindow: true,
    );
    return result?.files.single.path;
  }

  Future<void> setDataDirectory(String targetPath) async {
    final sourceDb = await databaseFile();
    final sourceAttachments = await attachmentsDirectory();
    final targetDir = Directory(targetPath);
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    await _copyFileIfExists(
      sourceDb,
      File(p.join(targetDir.path, databaseFileName)),
    );
    await _copyDirectory(
      sourceAttachments,
      Directory(p.join(targetDir.path, attachmentsDirectoryName)),
    );
    await _writePreferencesSnapshot(
      File(p.join(targetDir.path, preferencesFileName)),
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(dataDirectoryPrefKey, targetDir.path);
  }

  // 快照落盘防抖：2 秒内多次小改动合并为一次全量写入
  static Timer? _snapshotTimer;
  static bool _snapshotPending = false;

  Future<void> persistPreferencesSnapshot() async {
    _snapshotPending = true;
    _snapshotTimer ??= Timer(const Duration(seconds: 2), () {
      _snapshotTimer = null;
      _flushSnapshot();
    });
  }

  /// 立即落盘（退出 / 显式保存路径调用），合并掉尚未触发的防抖写入
  Future<void> flushNow() async {
    _snapshotTimer?.cancel();
    _snapshotTimer = null;
    if (!_snapshotPending) return;
    await _flushSnapshot();
  }

  Future<void> _flushSnapshot() async {
    _snapshotPending = false;
    try {
      await _writePreferencesSnapshot(
        File(p.join(await activeDataDirectoryPath(), preferencesFileName)),
      );
    } catch (_) {}
  }

  Future<String?> exportBackup() async {
    final output = await FilePicker.platform.saveFile(
      dialogTitle: '导出本地数据备份',
      fileName:
          'smart_assistant_local_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.zip',
      type: FileType.custom,
      allowedExtensions: const ['zip'],
      lockParentWindow: true,
    );
    if (output == null) return null;
    final outputPath = output.toLowerCase().endsWith('.zip')
        ? output
        : '$output.zip';
    await writeBackup(File(outputPath));
    return outputPath;
  }

  Future<void> writeBackup(File output) async {
    final archive = Archive();
    final db = await databaseFile();
    if (await db.exists()) {
      final bytes = await db.readAsBytes();
      archive.addFile(ArchiveFile(databaseFileName, bytes.length, bytes));
    }

    final prefsBytes = utf8.encode(json.encode(await _preferencesSnapshot()));
    archive.addFile(
      ArchiveFile(preferencesFileName, prefsBytes.length, prefsBytes),
    );

    final attachments = await attachmentsDirectory();
    if (await attachments.exists()) {
      await for (final entity in attachments.list(recursive: true)) {
        if (entity is! File) continue;
        final relative = p.relative(entity.path, from: attachments.path);
        final name = p
            .join(attachmentsDirectoryName, relative)
            .replaceAll('\\', '/');
        final bytes = await entity.readAsBytes();
        archive.addFile(ArchiveFile(name, bytes.length, bytes));
      }
    }

    final encoded = ZipEncoder().encode(archive);
    if (encoded == null) {
      throw StateError('Failed to encode local data backup.');
    }
    if (!await output.parent.exists()) {
      await output.parent.create(recursive: true);
    }
    await output.writeAsBytes(encoded, flush: true);
  }

  Future<String> importBackupToNewDirectory(String zipPath) async {
    final docs = await getApplicationDocumentsDirectory();
    final target = Directory(
      p.join(
        docs.path,
        'local_data_imports',
        DateFormat('yyyyMMdd_HHmmss').format(DateTime.now()),
      ),
    );
    await importBackupToDirectory(zipPath, target.path);
    return target.path;
  }

  Future<void> importBackupToDirectory(
    String zipPath,
    String targetPath,
  ) async {
    final source = File(zipPath);
    if (!await source.exists()) {
      throw StateError('Backup file does not exist.');
    }

    final target = Directory(targetPath);
    if (!await target.exists()) {
      await target.create(recursive: true);
    }

    final archive = ZipDecoder().decodeBytes(await source.readAsBytes());
    var hasDatabase = false;
    for (final file in archive.files) {
      if (!file.isFile) continue;
      final safeName = _safeArchiveName(file.name);
      if (safeName == null) continue;
      final outFile = File(p.join(target.path, safeName));
      if (!await outFile.parent.exists()) {
        await outFile.parent.create(recursive: true);
      }
      final content = file.content as List<int>;
      await outFile.writeAsBytes(content, flush: true);
      if (safeName == databaseFileName) hasDatabase = true;
    }
    if (!hasDatabase) {
      throw StateError('Backup does not contain $databaseFileName.');
    }

    final prefsFile = File(p.join(target.path, preferencesFileName));
    if (await prefsFile.exists()) {
      await _applyPreferencesSnapshot(prefsFile);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(dataDirectoryPrefKey, target.path);
  }

  Future<Map<String, Object?>> _preferencesSnapshot() async {
    final prefs = await SharedPreferences.getInstance();
    final data = <String, Object?>{};
    for (final key in prefs.getKeys()) {
      if (key == dataDirectoryPrefKey) continue;
      final value = prefs.get(key);
      if (value is bool ||
          value is int ||
          value is double ||
          value is String ||
          value is List<String>) {
        data[key] = value;
      }
    }
    return data;
  }

  Future<void> _writePreferencesSnapshot(File file) async {
    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(await _preferencesSnapshot()),
      flush: true,
    );
  }

  Future<void> _applyPreferencesSnapshot(File file) async {
    final raw = json.decode(await file.readAsString());
    if (raw is! Map<String, dynamic>) return;
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys().toList()) {
      if (key != dataDirectoryPrefKey) {
        await prefs.remove(key);
      }
    }
    for (final entry in raw.entries) {
      final key = entry.key;
      final value = entry.value;
      if (key == dataDirectoryPrefKey) continue;
      if (value is bool) {
        await prefs.setBool(key, value);
      } else if (value is int) {
        await prefs.setInt(key, value);
      } else if (value is double) {
        await prefs.setDouble(key, value);
      } else if (value is String) {
        await prefs.setString(key, value);
      } else if (value is List) {
        await prefs.setStringList(key, value.whereType<String>().toList());
      }
    }
  }

  Future<void> _copyFileIfExists(File source, File target) async {
    if (!await source.exists()) return;
    if (p.equals(p.normalize(source.path), p.normalize(target.path))) return;
    if (!await target.parent.exists()) {
      await target.parent.create(recursive: true);
    }
    final temp = File('${target.path}.tmp');
    await source.copy(temp.path);
    if (await target.exists()) {
      await target.delete();
    }
    await temp.rename(target.path);
  }

  Future<void> _copyDirectory(Directory source, Directory target) async {
    if (!await source.exists()) return;
    if (!await target.exists()) {
      await target.create(recursive: true);
    }
    await for (final entity in source.list(recursive: true)) {
      if (entity is! File) continue;
      final relative = p.relative(entity.path, from: source.path);
      await _copyFileIfExists(entity, File(p.join(target.path, relative)));
    }
  }

  String? _safeArchiveName(String name) {
    final normalized = p.normalize(name).replaceAll('\\', '/');
    if (normalized.startsWith('../') ||
        normalized == '..' ||
        p.isAbsolute(normalized)) {
      return null;
    }
    return normalized;
  }
}
