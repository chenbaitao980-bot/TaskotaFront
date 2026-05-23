import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../../../core/theme/app_theme.dart';
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
      'message': '你好！我是你的 AI 日程管家 👋\n\n'
          '我可以帮你：\n'
          '• 拆解大目标为可执行的小任务\n'
          '• 识别自然语言中的日程安排\n\n'
          '告诉我你想达成什么目标吧！',
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
        onError: (_) => setState(() => _isListening = false),
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
        const SnackBar(content: Text('语音功能需要系统语音包支持')),
      );
      return;
    }
    if (_isListening) {
      _speech.stop();
      setState(() => _isListening = false);
      return;
    }
    _speech.listen(
      localeId: 'zh_CN',
      onResult: (result) {
        if (result.finalResult) {
          _messageController.text = result.recognizedWords;
          setState(() => _isListening = false);
        }
      },
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

  void _quickAction(String message) {
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
      final profile = _storage.getExplicitProfile();
      final implicit = _storage.getImplicitProfile();
      final userProfile = <String, dynamic>{};
      if (profile != null) userProfile.addAll(profile);
      if (implicit != null) userProfile.addAll(implicit);
      userProfile['completionRate'] = implicit?['avgTaskCompletionRate'] ?? 0.0;

      final response = await _aiService.chat(
        userMessage: userMessage,
        history: history,
        userProfile: userProfile,
      );
      _addMessage(isUser: false, message: response);

      // 为 AI 提问自动生成建议回复选项
      final trimmed = response.trim();
      if (trimmed.endsWith('？') || trimmed.endsWith('?') || trimmed.endsWith('？\n') || trimmed.endsWith('?\n')) {
        final suggestions = _generateSuggestions(trimmed);
        if (suggestions.isNotEmpty) {
          setState(() {
            _messages.last['suggestions'] = suggestions;
          });
        }
      }

      final parsed = await _aiService.parseSchedule(userMessage);
      if (parsed != null && parsed['type'] == 'schedule') {
        setState(() => _pendingSchedule = parsed);
        _messages.last['action'] = 'schedule_confirm';
        _messages.last['scheduleData'] = parsed;
        setState(() {});
      }
    } catch (e) {
      _addMessage(isUser: false, message: '抱歉，AI 服务暂时不可用，请检查网络后重试。');
    } finally {
      if (mounted) setState(() => _isTyping = false);
    }
  }

  /// 根据 AI 消息关键词生成建议回复按钮
  /// 优先级：目标 > 时间 > 水平 > 确认
  /// 时间关键词只匹配明确的时间单位（每天/每周/多久），不匹配泛化的"时间"二字
  /// 避免"时间期望""什么时间"等非每日时长问题被误匹配
  List<String> _generateSuggestions(String aiMessage) {
    if (aiMessage.contains('目标') || aiMessage.contains('想达到') || aiMessage.contains('希望') || aiMessage.contains('期限')) {
      return ['简单入门就好', '达到中级水平', '希望精通'];
    }
    if (aiMessage.contains('每天') || aiMessage.contains('每周') || aiMessage.contains('多久') || aiMessage.contains('小时') || aiMessage.contains('分钟')) {
      return ['每天30分钟', '每天1小时', '每天2小时以上'];
    }
    if (aiMessage.contains('水平') || aiMessage.contains('基础') || aiMessage.contains('学过')) {
      return ['零基础', '会一点点', '有一些基础'];
    }
    if (aiMessage.contains('确认') || aiMessage.contains('理解') || aiMessage.contains('对吗') || aiMessage.contains('是不是')) {
      return ['是的，没错', '不太准确', '让我重新说'];
    }
    return ['好的，继续', '让我想想', '换个方向'];
  }

  void _suggestionClicked(String text) {
    _addMessage(isUser: true, message: text);
    _callAI(text);
  }

  List<Map<String, String>> _buildHistory() {
    final history = <Map<String, String>>[];
    final start = _messages.length > 10 ? _messages.length - 10 : 0;
    for (var i = start; i < _messages.length - 1; i++) {
      final m = _messages[i];
      if (m['action'] != null) continue;
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
          const SnackBar(content: Text('日程已添加 ✅')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('添加失败: $e')));
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
        title: const Text('AI 助手'),
        surfaceTintColor: Colors.transparent,
      ),
      body: Column(
        children: [
          Expanded(child: _buildMessageList()),
          if (_messages.where((m) => m['isUser'] as bool).isEmpty)
            _buildQuickActions(),
          if (_isTyping) _buildTypingIndicator(),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        final hasAction = msg['action'] != null;

        if (hasAction && msg['action'] == 'schedule_confirm') {
          return _buildScheduleConfirmCard(msg);
        }

        return _buildBubble(msg);
      },
    );
  }

  Widget _buildBubble(Map<String, dynamic> msg) {
    final text = msg['message'] as String;
    final isUser = msg['isUser'] as bool;
    final suggestions = msg['suggestions'] as List<String>?;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isUser) ...[
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.auto_awesome, size: 18, color: AppTheme.primaryColor),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Container(
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isUser ? AppTheme.bgInput : AppTheme.bgCard,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(12),
                      topRight: const Radius.circular(12),
                      bottomLeft: isUser ? const Radius.circular(12) : const Radius.circular(4),
                      bottomRight: isUser ? const Radius.circular(4) : const Radius.circular(12),
                    ),
                    border: isUser
                        ? const Border(left: BorderSide(color: AppTheme.primaryColor, width: 3))
                        : null,
                  ),
                  child: Text(text, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14, height: 1.5)),
                ),
              ),
              if (isUser) const SizedBox(width: 8),
            ],
          ),
          // AI 建议回复按钮
          if (!isUser && suggestions != null && suggestions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 40, top: 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: suggestions.map((s) {
                  return ActionChip(
                    label: Text(s, style: const TextStyle(fontSize: 12, color: AppTheme.primaryColor)),
                    onPressed: () => _suggestionClicked(s),
                    backgroundColor: AppTheme.bgInput,
                    side: BorderSide(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildScheduleConfirmCard(Map<String, dynamic> msg) {
    final data = msg['scheduleData'] as Map<String, dynamic>;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(mainAxisAlignment: MainAxisAlignment.start, children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.auto_awesome, size: 18, color: AppTheme.primaryColor),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.bgCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderSubtle),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.event, size: 16, color: AppTheme.primaryColor),
                const SizedBox(width: 6),
                Text(data['title'] ?? '日程', style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 15)),
              ]),
              const SizedBox(height: 8),
              Text('${data['start_time']}  →  ${data['end_time']}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(onPressed: () => setState(() => _pendingSchedule = null), child: const Text('忽略', style: TextStyle(color: AppTheme.textHint))),
                const SizedBox(width: 8),
                FilledButton.icon(onPressed: _importSchedule, icon: const Icon(Icons.add, size: 16), label: const Text('添加到日历'), style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryColor)),
              ]),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(left: 56, bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: AppTheme.bgCard, borderRadius: BorderRadius.circular(12)),
        child: Row(mainAxisSize: MainAxisSize.min, children: List.generate(3, (i) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppTheme.textHint, shape: BoxShape.circle)),
        ))),
      ),
    );
  }

  Widget _buildQuickActions() {
    const actions = [
      ('拆解目标', Icons.auto_fix_high, '我想拆解一个长期目标，帮我规划一下'),
      ('安排日程', Icons.event, '我想安排一个日程'),
      ('今日建议', Icons.lightbulb_outline, '给我今天的建议'),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '快捷操作',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: actions.map((a) {
              return ActionChip(
                avatar: Icon(a.$2, size: 16, color: AppTheme.primaryColor),
                label: Text(a.$1, style: const TextStyle(fontSize: 13)),
                onPressed: () => _quickAction(a.$3),
                backgroundColor: AppTheme.bgCard,
                side: BorderSide.none,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: const BoxDecoration(
        color: AppTheme.bgScaffold,
        border: Border(top: BorderSide(color: AppTheme.borderSubtle, width: 0.5)),
      ),
      child: Row(children: [
        IconButton(icon: Icon(_isListening ? Icons.mic : Icons.mic_outlined, color: _isListening ? AppTheme.error : AppTheme.textHint, size: 22), onPressed: _startListening),
        Expanded(child: TextField(
          controller: _messageController,
          onSubmitted: (_) => _sendMessage(),
          textInputAction: TextInputAction.send,
          style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary),
          decoration: InputDecoration(hintText: '输入目标或日程...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), isDense: true),
        )),
        const SizedBox(width: 4),
        Container(decoration: const BoxDecoration(color: AppTheme.primaryColor, shape: BoxShape.circle), child: IconButton(icon: const Icon(Icons.send_rounded, size: 18, color: Colors.white), onPressed: _sendMessage)),
      ]),
    );
  }
}
