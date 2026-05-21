part of 'ai_chat_bloc.dart';

abstract class AiChatEvent extends Equatable {
  const AiChatEvent();

  @override
  List<Object?> get props => [];
}

class SendMessage extends AiChatEvent {
  final String message;

  const SendMessage({required this.message});

  @override
  List<Object?> get props => [message];
}

class ReceiveMessage extends AiChatEvent {
  final String message;

  const ReceiveMessage({required this.message});

  @override
  List<Object?> get props => [message];
}

class ClearChat extends AiChatEvent {}
