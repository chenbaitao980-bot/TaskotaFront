import 'package:freezed_annotation/freezed_annotation.dart';

part 'ai_conversation.freezed.dart';
part 'ai_conversation.g.dart';

@freezed
class AiConversation with _$AiConversation {
  const factory AiConversation({
    required String id,
    required String userId,
    required String userInput,
    Map<String, dynamic>? aiResponse,
    Map<String, dynamic>? context,
    required DateTime createdAt,
  }) = _AiConversation;

  factory AiConversation.fromJson(Map<String, dynamic> json) =>
      _$AiConversationFromJson(json);
}
