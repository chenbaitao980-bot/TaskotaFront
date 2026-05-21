// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_conversation.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$AiConversationImpl _$$AiConversationImplFromJson(Map<String, dynamic> json) =>
    _$AiConversationImpl(
      id: json['id'] as String,
      userId: json['userId'] as String,
      userInput: json['userInput'] as String,
      aiResponse: json['aiResponse'] as Map<String, dynamic>?,
      context: json['context'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$$AiConversationImplToJson(
  _$AiConversationImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'userId': instance.userId,
  'userInput': instance.userInput,
  'aiResponse': instance.aiResponse,
  'context': instance.context,
  'createdAt': instance.createdAt.toIso8601String(),
};
