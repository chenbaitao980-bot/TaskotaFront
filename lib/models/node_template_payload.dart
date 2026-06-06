import 'dart:convert';
import 'dart:typed_data';

class NodeTemplateImage {
  final String fileName;
  final String? mimeType;
  final String base64Data;

  const NodeTemplateImage({
    required this.fileName,
    required this.mimeType,
    required this.base64Data,
  });

  Uint8List get bytes => base64Decode(base64Data);

  Map<String, dynamic> toJson() => {
    'fileName': fileName,
    'mimeType': mimeType,
    'base64Data': base64Data,
  };

  factory NodeTemplateImage.fromJson(Map<String, dynamic> json) {
    return NodeTemplateImage(
      fileName: json['fileName'] as String? ?? 'template_image.png',
      mimeType: json['mimeType'] as String?,
      base64Data: json['base64Data'] as String? ?? '',
    );
  }
}

class NodeTemplateSubtask {
  final String title;
  final String description;
  final List<NodeTemplateSubtask> children;

  const NodeTemplateSubtask({
    required this.title,
    this.description = '',
    this.children = const [],
  });

  Map<String, dynamic> toJson() => {
    'title': title,
    'description': description,
    'children': children.map((child) => child.toJson()).toList(),
  };

  factory NodeTemplateSubtask.fromJson(Map<String, dynamic> json) {
    return NodeTemplateSubtask(
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      children: ((json['children'] as List?) ?? const [])
          .whereType<Map>()
          .map(
            (child) =>
                NodeTemplateSubtask.fromJson(Map<String, dynamic>.from(child)),
          )
          .where((child) => child.title.trim().isNotEmpty)
          .toList(),
    );
  }
}

class NodeTemplatePayload {
  final List<String> checklistTitles;
  final List<NodeTemplateImage> images;
  final List<NodeTemplateSubtask> subtasks;

  const NodeTemplatePayload({
    this.checklistTitles = const [],
    this.images = const [],
    this.subtasks = const [],
  });

  static const empty = NodeTemplatePayload();

  Map<String, dynamic> toJson() => {
    'checklistTitles': checklistTitles,
    'images': images.map((image) => image.toJson()).toList(),
    'subtasks': subtasks.map((subtask) => subtask.toJson()).toList(),
  };

  factory NodeTemplatePayload.fromJson(Map<String, dynamic> json) {
    return NodeTemplatePayload(
      checklistTitles: ((json['checklistTitles'] as List?) ?? const [])
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList(),
      images: ((json['images'] as List?) ?? const [])
          .whereType<Map>()
          .map(
            (image) =>
                NodeTemplateImage.fromJson(Map<String, dynamic>.from(image)),
          )
          .where((image) => image.base64Data.isNotEmpty)
          .toList(),
      subtasks: ((json['subtasks'] as List?) ?? const [])
          .whereType<Map>()
          .map(
            (subtask) => NodeTemplateSubtask.fromJson(
              Map<String, dynamic>.from(subtask),
            ),
          )
          .where((subtask) => subtask.title.trim().isNotEmpty)
          .toList(),
    );
  }

  String encodeChecklist() => jsonEncode(checklistTitles);
  String encodeImages() => jsonEncode(images.map((i) => i.toJson()).toList());
  String encodeSubtasks() =>
      jsonEncode(subtasks.map((s) => s.toJson()).toList());

  static List<String> decodeChecklist(String raw) {
    final data = jsonDecode(raw);
    return ((data as List?) ?? const [])
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  static List<NodeTemplateImage> decodeImages(String raw) {
    final data = jsonDecode(raw);
    return ((data as List?) ?? const [])
        .whereType<Map>()
        .map(
          (image) =>
              NodeTemplateImage.fromJson(Map<String, dynamic>.from(image)),
        )
        .where((image) => image.base64Data.isNotEmpty)
        .toList();
  }

  static List<NodeTemplateSubtask> decodeSubtasks(String raw) {
    final data = jsonDecode(raw);
    return ((data as List?) ?? const [])
        .whereType<Map>()
        .map(
          (subtask) =>
              NodeTemplateSubtask.fromJson(Map<String, dynamic>.from(subtask)),
        )
        .where((subtask) => subtask.title.trim().isNotEmpty)
        .toList();
  }
}
