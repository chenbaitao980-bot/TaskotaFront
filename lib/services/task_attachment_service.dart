import 'dart:io';
import 'package:drift/drift.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../data/database/app_database.dart' as db
    show AppDatabase, TaskAttachment, TaskAttachmentsCompanion;

/// 公开数据模型（仅展示层使用），内部保持 Drift TaskAttachment 行
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

  /// 兼容旧调用：filePath = localPath（保留 getter）
  String? get filePath => localPath;

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
  static final TaskAttachmentService _instance = TaskAttachmentService._();
  factory TaskAttachmentService() => _instance;
  TaskAttachmentService._();

  static const _bucket = 'task_attachments';
  static const _uuid = Uuid();

  db.AppDatabase? _db;
  void bind(db.AppDatabase d) {
    _db = d;
  }

  SupabaseClient get _supa => Supabase.instance.client;
  String? get _userId => _supa.auth.currentUser?.id;

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

  /// 保存：写本地 → 上传 Storage → 写 db → push 到云
  Future<TaskAttachment> saveAttachment(String taskId, PlatformFile file) async {
    if (_db == null) throw StateError('AttachmentService not bound to db');
    final userId = _userId;
    final id = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;

    // 1) 写本地缓存
    final taskDir = await _taskDir(taskId);
    final destPath = p.join(taskDir, '${id}_${file.name}');
    if (file.path != null) {
      await File(file.path!).copy(destPath);
    }

    // 2) 计算 storage_path 并上传
    final storagePath = userId != null
        ? '$userId/$taskId/${id}_${file.name}'
        : '_local/$taskId/${id}_${file.name}';
    if (userId != null && file.path != null) {
      try {
        await _supa.storage.from(_bucket).upload(
              storagePath,
              File(file.path!),
              fileOptions: const FileOptions(upsert: true),
            );
        print('[Attach] ✓ uploaded $storagePath');
      } catch (e) {
        print('[Attach] ❌ upload 失败 $storagePath: $e');
      }
    }

    // 3) 写本地 db
    final row = db.TaskAttachmentsCompanion(
      id: Value(id),
      taskId: Value(taskId),
      fileName: Value(file.name),
      localPath: Value(destPath),
      storagePath: Value(storagePath),
      sizeBytes: Value(file.size),
      mimeType: Value(_guessMime(file.name)),
      addedAt: Value(now),
      updatedAt: Value(now),
    );
    await _db!.into(_db!.taskAttachments).insertOnConflictUpdate(row);

    // 4) push 云端 metadata
    if (userId != null) {
      try {
        await _supa.from('task_attachments').upsert({
          'id': id,
          'user_id': userId,
          'task_id': taskId,
          'file_name': file.name,
          'storage_path': storagePath,
          'size_bytes': file.size,
          'mime_type': _guessMime(file.name),
          'added_at': now,
          'updated_at': now,
        });
        print('[Attach] ✓ pushed metadata $id');
      } catch (e) {
        print('[Attach] ❌ push metadata 失败 $id: $e');
      }
    }

    return TaskAttachment(
      id: id,
      taskId: taskId,
      fileName: file.name,
      localPath: destPath,
      storagePath: storagePath,
      sizeBytes: file.size,
      mimeType: _guessMime(file.name),
      addedAt: now,
    );
  }

  Future<List<TaskAttachment>> getAttachments(String taskId) async {
    if (_db == null) return [];
    final rows = await (_db!.select(_db!.taskAttachments)
          ..where((t) => t.taskId.equals(taskId))
          ..orderBy([(t) => OrderingTerm(expression: t.addedAt)]))
        .get();
    return rows.map(TaskAttachment.fromRow).toList();
  }

  /// 打开附件：本地无文件则先从 Storage 下载到本地
  Future<File?> ensureLocalFile(TaskAttachment att) async {
    if (att.localPath != null && File(att.localPath!).existsSync()) {
      return File(att.localPath!);
    }
    if (_userId == null) return null;
    try {
      final bytes = await _supa.storage.from(_bucket).download(att.storagePath);
      final taskDir = await _taskDir(att.taskId);
      final destPath = p.join(taskDir, '${att.id}_${att.fileName}');
      final f = await File(destPath).writeAsBytes(bytes);
      // 更新本地 db 的 localPath
      if (_db != null) {
        await (_db!.update(_db!.taskAttachments)
              ..where((t) => t.id.equals(att.id)))
            .write(db.TaskAttachmentsCompanion(localPath: Value(destPath)));
      }
      print('[Attach] ✓ downloaded ${att.storagePath} → $destPath');
      return f;
    } catch (e) {
      print('[Attach] ❌ download 失败 ${att.storagePath}: $e');
      return null;
    }
  }

  Future<void> deleteAttachment(String taskId, dynamic filePathOrId) async {
    if (_db == null) return;
    // 兼容旧签名：传入 localPath 字符串
    String? attId;
    if (filePathOrId is String) {
      final rows = await (_db!.select(_db!.taskAttachments)
            ..where((t) => t.taskId.equals(taskId) &
                (t.id.equals(filePathOrId) | t.localPath.equals(filePathOrId))))
          .get();
      attId = rows.isNotEmpty ? rows.first.id : null;
    }
    if (attId == null) return;
    final row = await (_db!.select(_db!.taskAttachments)
          ..where((t) => t.id.equals(attId!)))
        .getSingleOrNull();
    if (row == null) return;

    // 1) 本地文件
    if (row.localPath != null) {
      final f = File(row.localPath!);
      if (f.existsSync()) f.deleteSync();
    }
    // 2) 本地 db
    await (_db!.delete(_db!.taskAttachments)..where((t) => t.id.equals(attId!))).go();
    // 3) Storage
    if (_userId != null) {
      try {
        await _supa.storage.from(_bucket).remove([row.storagePath]);
      } catch (e) {
        print('[Attach] ❌ Storage remove 失败 ${row.storagePath}: $e');
      }
      try {
        await _supa.from('task_attachments').delete().eq('id', attId);
      } catch (e) {
        print('[Attach] ❌ metadata delete 失败 $attId: $e');
      }
    }
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

  String _guessMime(String name) {
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    switch (ext) {
      case 'pdf': return 'application/pdf';
      case 'png': return 'image/png';
      case 'jpg': case 'jpeg': return 'image/jpeg';
      case 'gif': return 'image/gif';
      case 'md': return 'text/markdown';
      case 'txt': return 'text/plain';
      case 'json': return 'application/json';
      case 'zip': return 'application/zip';
      case 'doc': case 'docx': return 'application/msword';
      case 'xls': case 'xlsx': return 'application/vnd.ms-excel';
      default: return 'application/octet-stream';
    }
  }
}

