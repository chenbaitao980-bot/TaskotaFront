part of 'ai_chat_bloc.dart';

abstract class AiChatState extends Equatable {
  const AiChatState();

  @override
  List<Object?> get props => [];
}

class AiChatInitial extends AiChatState {}

class AiChatLoading extends AiChatState {}

class AiChatMessageSent extends AiChatState {
  final String message;

  const AiChatMessageSent({required this.message});

  @override
  List<Object?> get props => [message];
}

class AiChatMessageReceived extends AiChatState {
  final String message;

  const AiChatMessageReceived({required this.message});

  @override
  List<Object?> get props => [message];
}

class AiChatError extends AiChatState {
  final String message;

  const AiChatError({required this.message});

  @override
  List<Object?> get props => [message];
}
