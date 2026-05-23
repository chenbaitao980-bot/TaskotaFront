import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../../../services/ai_service.dart';
import '../../../services/local_storage_service.dart';
import '../../blocs/auth/auth_bloc.dart';

class AiChatPage extends StatefulWidget {
  const AiChatPage({super.key});

  @override
  State<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends State<AiChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  final ScrollController _scrollController = ScrollController();
  final AIService _aiService = AIService();
  final LocalStorageService _storage = LocalStorageService();
  final SpeechToText _speech = SpeechToText();
  bool _isTyping = false;
  bool _speechAvailable = false;
  bool _isListening = false;
  Map<String, dynamic>? _pendingSchedule;

  @override
  void initState() {
    super.initState();
    _storage.init();
    _initSpeech();
    _messages.add({
      'isUser': false,
      'message': '你好！我是你的AI日程管家。我可以帮你：\n\n'
          '• 拆解大目标为可执行的小任务\n'
          '• 识别自然语言中的日程安排\n'
          '• 检测日程冲突并给出建议\n'
          '• 追踪进度并提供反馈\n\n'
          '告诉我你想达成什么目标吧！\n\n'
          '💡 试试说："明天下午3点开会1小时" 或 "我想今年拿下日语N1"',
      'time': DateTime.now(),
    });
  }

  Future<void> _initSpeech() async {
    try {
      final available = await _speech.initialize(
        onStatus: (status) {
          if (status == 'done' && _isListening) {
            setState(() => _isListening = false);
          }
        },
        onError: (error) {
          setState(() => _isListening = false);
        },
      );
      setState(() => _speechAvailable = available);
    } catch (_) {
      setState(() => _speechAvailable = false);
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _speech.cancel();
    super.dispose();
  }

  String _getUserId() {
    final state = context.read<AuthBloc>().state;
    if (state is LocalAuthenticated) return state.email;
    if (state is Authenticated) return state.user.id;
    return 'local_user';
  }

  void _startListening() {
    if (!_speechAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('语音功能需要系统语音语言包支持。Windows: 设置 → 时间和语言 → 语音 → 安装中文语音包'),
          duration: Duration(seconds: 5),
        ),
      );
      return;
    }

    if (_isListening) {
      _speech.stop();
      setState(() => _isListening = false);
      return;
    }

    _speech.listen(
      onResult: (result) {
        if (result.finalResult) {
          _messageController.text = result.recognizedWords;
          setState(() => _isListening = false);
        }
      },
      localeId: 'zh_CN',
    );
    setState(() => _isListening = true);
  }

  void _sendMessage() {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    _addMessage(isUser: true, message: message);
    _messageController.clear();
    _callAI(message);
  }

  void _addMessage({required bool isUser, required String message}) {
    setState(() {
      _messages.add({'isUser': isUser, 'message': message, 'time': DateTime.now()});
    });
    _scrollToBottom();
  }

  Future<void> _callAI(String userMessage) async {
    setState(() => _isTyping = true);

    try {
      final history = _buildHistory();
      final response = await _aiService.chat(userMessage: userMessage, history: history);

      _addMessage(isUser: false, message: response);

      // Try to parse as schedule
      final parsed = await _aiService.parseSchedule(userMessage);
      if (parsed != null && parsed['type'] == 'schedule') {
        setState(() => _pendingSchedule = parsed);
        _addMessage(
          isUser: false,
          message: '📋 检测到日程信息:\n'
              '标题: ${parsed['title']}\n'
              '开始: ${parsed['start_time']}\n'
              '结束: ${parsed['end_time']}\n\n'
              '点击下方按钮添加到日历 ⬇️',
        );
      }
    } catch (e) {
      _addMessage(isUser: false, message: '抱歉，AI服务暂时不可用，请检查网络连接后重试。\n错误: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isTyping = false;
        });
      }
    }
  }

  List<Map<String, String>> _buildHistory() {
    final history = <Map<String, String>>[];
    final recent = _messages.length > 6 ? _messages.sublist(_messages.length - 6) : _messages;
    for (final m in recent) {
      if (m['isUser'] as bool) {
        history.add({'role': 'user', 'content': m['message'] as String});
      } else {
        history.add({'role': 'assistant', 'content': m['message'] as String});
      }
    }
    return history;
  }

  Future<void> _importSchedule() async {
    if (_pendingSchedule == null) return;

    try {
      final startTime = DateTime.parse(_pendingSchedule!['start_time'] as String);
      final endTime = DateTime.parse(_pendingSchedule!['end_time'] as String);

      await _storage.createSchedule(
        userId: _getUserId(),
        title: _pendingSchedule!['title'] as String,
        startTime: startTime,
        endTime: endTime,
        priority: _pendingSchedule!['priority'] as String? ?? 'P2',
      );

      setState(() => _pendingSchedule = null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('日程已添加到日历 ✅')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('添加失败: $e')),
        );
      }
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.smart_toy, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('AI小管家', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Text(
                _isTyping ? '正在输入...' : '在线',
                style: TextStyle(fontSize: 12, color: _isTyping ? Colors.orange : Colors.green),
              ),
            ],
          ),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: _messages.length + (_pendingSchedule != null ? 1 : 0),
            itemBuilder: (context, index) {
              if (index < _messages.length) {
                return _buildMessageBubble(_messages[index]);
              }
              // Pending schedule import button
              return Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '检测到日程: ${_pendingSchedule!['title']}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: _importSchedule,
                        icon: const Icon(Icons.calendar_month, size: 18),
                        label: const Text('添加到日历'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        if (_isTyping)
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 8),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  _buildDot(0), _buildDot(1), _buildDot(2),
                ]),
              ),
            ]),
          ),
        _buildInputArea(),
      ]),
    );
  }

  Widget _buildDot(int index) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 2),
      width: 8, height: 8,
      decoration: BoxDecoration(color: Colors.grey[400], shape: BoxShape.circle),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message) {
    final isUser = message['isUser'] as bool;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isUser ? Theme.of(context).colorScheme.primary : Colors.grey[200],
          borderRadius: BorderRadius.circular(20).copyWith(
            bottomRight: isUser ? const Radius.circular(4) : null,
            bottomLeft: !isUser ? const Radius.circular(4) : null,
          ),
        ),
        child: Text(
          message['message'],
          style: TextStyle(color: isUser ? Colors.white : Colors.black87, fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.grey.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, -5)),
        ],
      ),
      child: SafeArea(
        child: Row(children: [
          GestureDetector(
            onTap: _startListening,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isListening ? Colors.red : (_speechAvailable ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1) : Colors.grey[200]),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isListening ? Icons.mic : Icons.mic_none,
                color: _isListening ? Colors.white : (_speechAvailable ? Theme.of(context).colorScheme.primary : Colors.grey),
                size: 24,
              ),
            ),
          ),
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: '输入目标或问题...',
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send, color: Colors.white, size: 20),
            ),
          ),
        ]),
      ),
    );
  }
}
