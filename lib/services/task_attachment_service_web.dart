import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import '../data/database/app_database.dart'
    as db
    show AppDatabase, TaskAttachment;

class TaskAttachment {
  final String id;
  final String taskId;
  final String fileName;
  final String? localPath;
  final String storagePath;
  final int? sizeBytes;
  final String? mimeType;
  final int addedAt;

  const TaskAttachment({
    required this.id,
    required this.taskId,
    required this.fileName,
    required this.localPath,
    required this.storagePath,
    required this.sizeBytes,
    required this.mimeType,
    required this.addedAt,
  });

  String? get filePath => localPath;
  bool get isImage => TaskAttachmentService.isImageFile(fileName, mimeType);

  factory TaskAttachment.fromRow(db.TaskAttachment row) => TaskAttachment(
    id: row.id,
    taskId: row.taskId,
    fileName: row.fileName,
    localPath: row.localPath,
    storagePath: row.storagePath,
    sizeBytes: row.sizeBytes,
    mimeType: row.mimeType,
    addedAt: row.addedAt,
  );
}

class TaskAttachmentService {
  static final TaskAttachmentService _instance =
      TaskAttachmentService._internal();
  factory TaskAttachmentService() => _instance;
  TaskAttachmentService._internal();

  void bind(db.AppDatabase database) {}

  static bool isImageFile(String fileName, String? mimeType) {
    if (mimeType != null) {
      return mimeType.startsWith('image/');
    }
    final lower = fileName.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.heic');
  }

  Future<List<TaskAttachment>> getAttachments(String taskId) async => [];

  Future<dynamic> ensureLocalFile(TaskAttachment attachment) async => null;

  Future<PlatformFile?> pickFile() async => null;

  Future<PlatformFile?> pickImageFile() async => null;

  Future<void> saveAttachment(String taskId, PlatformFile file) async {}

  Future<void> deleteAttachment(String taskId, dynamic filePathOrId) async {}

  Future<TaskAttachment> saveImageBytes(
    String taskId, {
    required String fileName,
    required Uint8List bytes,
  }) async {
    // Web stub — no local file storage; return a placeholder attachment
    final now = DateTime.now().millisecondsSinceEpoch;
    return TaskAttachment(
      id: '',
      taskId: taskId,
      fileName: fileName,
      localPath: null,
      storagePath: '',
      sizeBytes: bytes.length,
      mimeType: null,
      addedAt: now,
    );
  }

  Future<String> readFileContent(String filePath) async => '';

  Future<void> deleteAttachmentsForTask(String taskId) async {}

  Future<String?> getDownloadUrl(TaskAttachment attachment) async => null;
}
