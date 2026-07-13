import 'dart:convert';

class AssistantModelConfig {
  final String baseUrl;
  final String apiPath;
  final String apiKey;
  final String model;

  const AssistantModelConfig({
    this.baseUrl = '',
    this.apiPath = '/chat/completions',
    this.apiKey = '',
    this.model = '',
  });

  bool get isComplete =>
      baseUrl.trim().isNotEmpty &&
      apiKey.trim().isNotEmpty &&
      model.trim().isNotEmpty;

  String get endpoint {
    final base = _normalizedBaseUrl(
      baseUrl.trim().replaceFirst(RegExp(r'/+$'), ''),
    );
    if (base.endsWith('/chat/completions')) return base;
    final path = apiPath.trim().isEmpty ? '/chat/completions' : apiPath.trim();
    return '$base${path.startsWith('/') ? path : '/$path'}';
  }

  String _normalizedBaseUrl(String value) {
    final lower = value.toLowerCase();
    if (lower.contains('ark.cn-beijing.volces.com/api/coding')) {
      if (lower.endsWith('/api/coding/v3')) return value;
      return value.replaceFirst(
        RegExp(r'/api/coding$', caseSensitive: false),
        '/api/coding/v3',
      );
    }
    return value;
  }

  AssistantModelConfig copyWith({
    String? baseUrl,
    String? apiPath,
    String? apiKey,
    String? model,
  }) {
    return AssistantModelConfig(
      baseUrl: baseUrl ?? this.baseUrl,
      apiPath: apiPath ?? this.apiPath,
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
    );
  }

  Map<String, dynamic> toJson() => {
    'baseUrl': baseUrl,
    'apiPath': apiPath,
    'apiKey': apiKey,
    'model': model,
  };

  factory AssistantModelConfig.fromJson(Map<String, dynamic> json) {
    return AssistantModelConfig(
      baseUrl: json['baseUrl'] as String? ?? '',
      apiPath: json['apiPath'] as String? ?? '/chat/completions',
      apiKey: json['apiKey'] as String? ?? '',
      model: json['model'] as String? ?? '',
    );
  }
}

class AssistantSource {
  final String type;
  final String title;
  final String snippet;
  final String? id;

  const AssistantSource({
    required this.type,
    required this.title,
    required this.snippet,
    this.id,
  });

  Map<String, dynamic> toJson() => {
    'type': type,
    'title': title,
    'snippet': snippet,
    'id': id,
  };

  factory AssistantSource.fromJson(Map<String, dynamic> json) {
    return AssistantSource(
      type: json['type'] as String? ?? 'unknown',
      title: json['title'] as String? ?? '',
      snippet: json['snippet'] as String? ?? '',
      id: json['id'] as String?,
    );
  }
}

class AssistantToolCall {
  final String id;
  final String name;
  final String arguments;

  const AssistantToolCall({
    required this.id,
    required this.name,
    required this.arguments,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'arguments': arguments,
  };

  factory AssistantToolCall.fromJson(Map<String, dynamic> json) {
    return AssistantToolCall(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      arguments: json['arguments'] as String? ?? '{}',
    );
  }
}

class AssistantMessage {
  final String role;
  final String content;
  final DateTime createdAt;
  final String reasoningContent;
  final String? toolName;
  final String? toolCallId;
  final List<AssistantToolCall> toolCalls;
  final List<AssistantSource> sources;

  const AssistantMessage({
    required this.role,
    required this.content,
    required this.createdAt,
    this.reasoningContent = '',
    this.toolName,
    this.toolCallId,
    this.toolCalls = const [],
    this.sources = const [],
  });

  bool get isUser => role == 'user';
  bool get isAssistant => role == 'assistant' || role == 'ai';
  bool get isTool => role == 'tool';

  Map<String, dynamic> toJson() => {
    'role': role,
    'content': content,
    'createdAt': createdAt.toIso8601String(),
    'reasoningContent': reasoningContent,
    'toolName': toolName,
    'toolCallId': toolCallId,
    'toolCalls': toolCalls.map((e) => e.toJson()).toList(),
    'sources': sources.map((e) => e.toJson()).toList(),
  };

  factory AssistantMessage.fromJson(Map<String, dynamic> json) {
    return AssistantMessage(
      role: json['role'] as String? ?? 'assistant',
      content: json['content'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      reasoningContent: json['reasoningContent'] as String? ?? '',
      toolName: json['toolName'] as String?,
      toolCallId: json['toolCallId'] as String?,
      toolCalls: (json['toolCalls'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(AssistantToolCall.fromJson)
          .toList(),
      sources: (json['sources'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(AssistantSource.fromJson)
          .toList(),
    );
  }
}

class AssistantToolExecution {
  final String toolName;
  final String content;
  final List<AssistantSource> sources;

  const AssistantToolExecution({
    required this.toolName,
    required this.content,
    this.sources = const [],
  });
}

Map<String, Object?> decodeAssistantJsonObject(String raw) {
  try {
    final decoded = jsonDecode(raw.isEmpty ? '{}' : raw);
    if (decoded is Map) {
      return decoded.map((key, value) => MapEntry(key.toString(), value));
    }
  } on FormatException {
    return {};
  }
  return {};
}
