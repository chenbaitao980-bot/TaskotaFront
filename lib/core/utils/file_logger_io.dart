import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class FileLogger {
  static FileLogger? _instance;
  static FileLogger get instance => _instance ??= FileLogger._();
  FileLogger._();

  File? _logFile;
  String? _dirPath;
  bool _cleaned = false;
  final _buffer = StringBuffer();
  Timer? _flushTimer;

  Future<void> _ensureFile() async {
    if (_logFile != null) return;
    final dir = await getApplicationDocumentsDirectory();
    _dirPath = '${dir.path}/logs';
    final logDir = Directory(_dirPath!);
    if (!await logDir.exists()) await logDir.create(recursive: true);

    if (!_cleaned) {
      _cleaned = true;
      await _cleanOldLogs();
    }

    final date = DateTime.now().toIso8601String().substring(0, 10);
    _logFile = File('$_dirPath/task_$date.log');
  }

  Future<void> _cleanOldLogs() async {
    if (_dirPath == null) return;
    try {
      final cutoff = DateTime.now().subtract(const Duration(days: 1));
      final logDir = Directory(_dirPath!);
      if (!await logDir.exists()) return;
      await for (final entry in logDir.list()) {
        if (entry is File && entry.path.endsWith('.log')) {
          final stat = await entry.stat();
          if (stat.modified.isBefore(cutoff)) {
            await entry.delete();
          }
        }
      }
    } catch (_) {}
  }

  Future<void> log(String message) async {
    final timestamp = DateTime.now().toIso8601String();
    _buffer.writeln('[$timestamp] $message');
    _flushTimer ??= Timer(const Duration(milliseconds: 500), _flush);
  }

  Future<void> _flush() async {
    _flushTimer = null;
    if (_buffer.isEmpty) return;
    final data = _buffer.toString();
    _buffer.clear();
    try {
      await _ensureFile();
      await _logFile!.writeAsString(data, mode: FileMode.append, flush: true);
    } catch (_) {}
  }

  Future<void> clear() async {
    try {
      await _ensureFile();
      await _logFile!.writeAsString(
        '===== SESSION ${DateTime.now().toIso8601String()} =====\n',
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
  if (!kReleaseMode) {
    // ignore: avoid_print
    print(message);
  }
}
