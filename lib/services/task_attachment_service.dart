import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class TaskAttachment {
  final String fileName;
  final String filePath;
  final int addedAt;

  const TaskAttachment({
    required this.fileName,
    required this.filePath,
    required this.addedAt,
  });

  Map<String, dynamic> toJson() => {
    'fileName': fileName,
    'filePath': filePath,
    'addedAt': addedAt,
  };

  factory TaskAttachment.fromJson(Map<String, dynamic> json) => TaskAttachment(
    fileName: json['fileName'] as String,
    filePath: json['filePath'] as String,
    addedAt: json['addedAt'] as int,
  );
}

class TaskAttachmentService {
  static final TaskAttachmentService _instance = TaskAttachmentService._();
  factory TaskAttachmentService() => _instance;
  TaskAttachmentService._();

  String? _basePath;

  Future<String> get _baseDir async {
    if (_basePath != null) return _basePath!;
    final appDir = await getApplicationDocumentsDirectory();
    _basePath = p.join(appDir.path, 'task_attachments');
    final dir = Directory(_basePath!);
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return _basePath!;
  }

  Future<String> _taskDir(String taskId) async {
    final base = await _baseDir;
    final dir = Directory(p.join(base, taskId));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir.path;
  }

  Future<PlatformFile?> pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return null;
    return result.files.first;
  }

  Future<TaskAttachment> saveAttachment(String taskId, PlatformFile file) async {
    final taskDir = await _taskDir(taskId);
    final destPath = p.join(taskDir, file.name);
    if (file.path != null) {
      await File(file.path!).copy(destPath);
    }
    final attachment = TaskAttachment(
      fileName: file.name,
      filePath: destPath,
      addedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await _appendMeta(taskId, attachment);
    return attachment;
  }

  Future<List<TaskAttachment>> getAttachments(String taskId) async {
    final metaFile = await _metaFile(taskId);
    if (!metaFile.existsSync()) return [];
    try {
      final content = metaFile.readAsStringSync();
      final List<dynamic> jsonList = jsonDecode(content);
      return jsonList.map((e) => TaskAttachment.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> deleteAttachment(String taskId, String filePath) async {
    final file = File(filePath);
    if (file.existsSync()) file.deleteSync();

    final attachments = await getAttachments(taskId);
    attachments.removeWhere((a) => a.filePath == filePath);
    await _writeMeta(taskId, attachments);
  }

  Future<String> readFileContent(String filePath) async {
    final file = File(filePath);
    if (!file.existsSync()) return '';
    try {
      return file.readAsStringSync();
    } catch (_) {
      return '[无法读取文件内容：二进制文件]';
    }
  }

  Future<void> _appendMeta(String taskId, TaskAttachment attachment) async {
    final existing = await getAttachments(taskId);
    existing.add(attachment);
    await _writeMeta(taskId, existing);
  }

  Future<void> _writeMeta(String taskId, List<TaskAttachment> attachments) async {
    final metaFile = await _metaFile(taskId);
    metaFile.writeAsStringSync(jsonEncode(attachments.map((a) => a.toJson()).toList()));
  }

  Future<File> _metaFile(String taskId) async {
    final taskDir = await _taskDir(taskId);
    return File(p.join(taskDir, '.meta.json'));
  }
}
