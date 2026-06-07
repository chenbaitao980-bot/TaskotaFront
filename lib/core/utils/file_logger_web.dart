class FileLogger {
  static FileLogger? _instance;
  static FileLogger get instance => _instance ??= FileLogger._();
  FileLogger._();

  Future<void> log(String message) async {
    print(message);
  }

  Future<void> clear() async {}

  Future<String> get filePath async => '(web: no file log)';
}

void flog(String message) {
  print(message);
}
