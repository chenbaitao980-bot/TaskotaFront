import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

part 'ai_chat_event.dart';
part 'ai_chat_state.dart';

class AiChatBloc extends Bloc<AiChatEvent, AiChatState> {
  AiChatBloc() : super(AiChatInitial()) {
    on<SendMessage>(_onSendMessage);
    on<ReceiveMessage>(_onReceiveMessage);
    on<ClearChat>(_onClearChat);
  }

  void _onSendMessage(SendMessage event, Emitter<AiChatState> emit) async {
    emit(AiChatLoading());
    
    // TODO: 调用AI API
    await Future.delayed(const Duration(seconds: 2));
    
    emit(AiChatMessageSent(message: event.message));
  }

  void _onReceiveMessage(ReceiveMessage event, Emitter<AiChatState> emit) {
    emit(AiChatMessageReceived(message: event.message));
  }

  void _onClearChat(ClearChat event, Emitter<AiChatState> emit) {
    emit(AiChatInitial());
  }
}
