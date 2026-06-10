import 'package:flutter/foundation.dart';

class FileLogger {
  static FileLogger? _instance;
  static FileLogger get instance => _instance ??= FileLogger._();
  FileLogger._();

  Future<void> log(String message) async {
    if (!kReleaseMode) {
      // ignore: avoid_print
      print(message);
    }
  }

  Future<void> clear() async {}

  Future<String> get filePath async => '(web: no file log)';
}

void flog(String message) {
  if (!kReleaseMode) {
    // ignore: avoid_print
    print(message);
  }
}
