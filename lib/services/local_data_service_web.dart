class LocalDataService {
  static const dataDirectoryPrefKey = 'local_data_directory';
  static const databaseFileName = 'smart_assistant.db';
  static const attachmentsDirectoryName = 'task_attachments';
  static const preferencesFileName = 'preferences.json';

  bool get isDesktop => false;

  Future<String?> configuredDataDirectory() async => null;

  Future<String> activeDataDirectoryPath() async => '';

  Future<dynamic> databaseFile() async => null;

  Future<dynamic> attachmentsDirectory() async => null;

  Future<String?> pickDataDirectory() async => null;

  Future<String?> pickBackupFile() async => null;

  Future<void> setDataDirectory(String targetPath) async {}

  Future<void> persistPreferencesSnapshot() async {}

  Future<String?> exportBackup() async => null;

  Future<void> writeBackup(dynamic output) async {}

  Future<String> importBackupToNewDirectory(String zipPath) async => '';

  Future<void> importBackupToDirectory(
    String zipPath,
    String targetPath,
  ) async {}
}
