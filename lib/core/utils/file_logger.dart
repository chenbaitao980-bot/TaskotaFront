import 'dart:io';
import 'package:path_provider/path_provider.dart';

class FileLogger {
  static FileLogger? _instance;
  static FileLogger get instance => _instance ??= FileLogger._();
  FileLogger._();

  File? _logFile;

  Future<void> _ensureFile() async {
    if (_logFile != null) return;
    final dir = await getApplicationDocumentsDirectory();
    _logFile = File('${dir.path}/task_debug.log');
  }

  Future<void> log(String message) async {
    try {
      await _ensureFile();
      final timestamp = DateTime.now().toIso8601String();
      await _logFile!.writeAsString(
        '[$timestamp] $message\n',
        mode: FileMode.append,
        flush: true,
      );
    } catch (_) {}
  }

  Future<void> clear() async {
    try {
      await _ensureFile();
      await _logFile!.writeAsString(
        '===== LOG CLEARED ${DateTime.now().toIso8601String()} =====\n',
      );
    } catch (_) {}
  }

  Future<String> get filePath async {
    await _ensureFile();
    return _logFile!.path;
  }
}

void flog(String message) {
  FileLogger.instance.log(message);
  print(message);
}
