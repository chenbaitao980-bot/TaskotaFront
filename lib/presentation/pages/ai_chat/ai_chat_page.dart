import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
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

class _AiChatPageState extends State<AiChatPage> with TickerProviderStateMixin {
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
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _storage.init();
    _initSpeech();
    _messages.add({
      'isUser': false,
      'message':
          '你好！我是你的 AI 日程管家 👋\n\n'
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
    _pulseController.dispose();
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('语音功能需要系统语音包支持')));
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
      _messages.add({
        'isUser': isUser,
        'message': message,
        'time': DateTime.now(),
      });
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
      final optionPayload = _extractExplicitOptions(response);
      final displayMessage = _cleanDisplayMarkdown(optionPayload.message);
      _addMessage(isUser: false, message: displayMessage);

      final trimmed = displayMessage.trim();
      final isPlan = _looksLikeFinalPlan(trimmed);
      if (isPlan) {
        setState(() {
          _messages.last['action'] = 'plan_view';
          _messages.last['planRows'] = _extractPlanRows(trimmed);
        });
      } else if (_canUseExplicitOptions(trimmed, optionPayload.suggestions)) {
        setState(() {
          _messages.last['suggestions'] = optionPayload.suggestions;
        });
      }
      if (!isPlan && _shouldSuggestForQuestion(trimmed)) {
        final suggestions = optionPayload.suggestions.isNotEmpty
            ? optionPayload.suggestions
            : _generateSuggestions(trimmed);
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

  List<String> _generateSuggestions(String aiMessage) {
    if (!_isShortQuestion(aiMessage) || _looksLikePlanContent(aiMessage)) {
      return const [];
    }
    if (aiMessage.contains('计划可以') ||
        aiMessage.contains('需要调整') ||
        aiMessage.contains('可以吗')) {
      return const [];
    }
    if (aiMessage.contains('每天') ||
        aiMessage.contains('每周') ||
        aiMessage.contains('多久') ||
        aiMessage.contains('小时') ||
        aiMessage.contains('分钟')) {
      return ['每天30分钟', '每天1小时', '每天2小时以上'];
    }
    if (aiMessage.contains('水平') ||
        aiMessage.contains('基础') ||
        aiMessage.contains('学过')) {
      return ['零基础', '会一点点', '有一些基础'];
    }
    if (aiMessage.contains('目标') ||
        aiMessage.contains('想达到') ||
        aiMessage.contains('希望') ||
        aiMessage.contains('期限')) {
      return ['简单入门就好', '达到中级水平', '希望精通'];
    }
    if (aiMessage.contains('确认') ||
        aiMessage.contains('理解') ||
        aiMessage.contains('对吗') ||
        aiMessage.contains('是不是')) {
      return ['是的，没错', '不太准确', '让我重新说'];
    }
    return ['好的，继续', '让我想想', '换个方向'];
  }

  bool _canUseExplicitOptions(String message, List<String> suggestions) {
    return suggestions.isNotEmpty &&
        _looksLikeQuestion(message) &&
        !_looksLikePlanContent(message);
  }

  bool _shouldSuggestForQuestion(String message) {
    return _looksLikeQuestion(message) &&
        _isShortQuestion(message) &&
        !_looksLikePlanContent(message);
  }

  bool _isShortQuestion(String message) {
    final normalized = message.replaceAll(RegExp(r'\s+'), '');
    return normalized.length <= 160 && message.split('\n').length <= 4;
  }

  bool _looksLikeQuestion(String message) {
    final trimmed = _cleanDisplayMarkdown(message).trim();
    return trimmed.endsWith('?') ||
        trimmed.endsWith('？') ||
        trimmed.contains('?') ||
        trimmed.contains('？') ||
        trimmed.contains('吗？') ||
        trimmed.contains('多少') ||
        trimmed.contains('什么');
  }

  bool _looksLikeFinalPlan(String message) {
    // 优先检测稳定标记 [TABLE_BEGIN]
    if (message.contains('[TABLE_BEGIN]') &&
        message.contains('[TABLE_END]')) {
      return true;
    }
    if (_looksLikePlanContent(message)) return true;
    final hasPlanWords =
        message.contains('第1周') ||
        message.contains('第 1 周') ||
        message.contains('计划') ||
        message.contains('里程碑') ||
        message.contains('执行层') ||
        message.contains('战术层');
    final hasMultipleSteps =
        RegExp(
          r'(第\s*\d+\s*[周月]|week\s*\d+)',
          caseSensitive: false,
        ).allMatches(message).length >=
        2;
    return hasPlanWords && hasMultipleSteps;
  }

  bool _looksLikePlanContent(String message) {
    final lines = message
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    final tableRows = lines.where((line) {
      final compact = line.replaceAll(' ', '');
      return line.contains('|') &&
          !RegExp(r'^\|?[:\-|]+\|?$').hasMatch(compact);
    }).length;
    final numberedRows = lines
        .where(
          (line) => RegExp(
            r'^(\d+[\.\、\)]|第\s*\d+|week\s*\d+)',
            caseSensitive: false,
          ).hasMatch(line),
        )
        .length;
    final bulletRows = lines
        .where((line) => line.startsWith('-') || line.startsWith('*'))
        .length;
    final hasPlanWords =
        message.contains('计划') ||
        message.contains('阶段') ||
        message.contains('任务') ||
        message.contains('流程') ||
        message.contains('里程碑') ||
        message.toLowerCase().contains('plan') ||
        message.toLowerCase().contains('schedule');

    return (tableRows >= 2 && hasPlanWords) ||
        (numberedRows >= 3 && hasPlanWords) ||
        (bulletRows >= 5 && hasPlanWords);
  }

  List<_PlanRow> _extractPlanRows(String message) {
    // 优先从 [TABLE_BEGIN]...[TABLE_END] 标记中解析
    final tableMatch = RegExp(
      r'\[TABLE_BEGIN\]\n(.*?)\[TABLE_END\]',
      dotAll: true,
    ).firstMatch(message);
    if (tableMatch != null) {
      final tableContent = tableMatch.group(1) ?? '';
      final rows = <_PlanRow>[];
      final lines = tableContent
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList();
      var stage = '计划';
      for (final line in lines) {
        final cells = _extractPlanTableCells(line);
        if (cells.length >= 2 && !_isPlanTableHeader(cells)) {
          stage = cells.first;
          rows.add(
            _PlanRow(
              stage: stage,
              task: cells.length >= 3 ? cells[1] : cells.join(' '),
              note: cells.length >= 3 ? cells.skip(2).join(' · ') : '阶段目标',
            ),
          );
          if (rows.length >= 12) break;
        }
      }
      if (rows.isNotEmpty) return rows;
    }

    final rows = <_PlanRow>[];
    final lines = message
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    var currentStage = '计划';
    for (final line in lines) {
      final cells = _extractPlanTableCells(line);
      if (cells.length >= 2 && !_isPlanTableHeader(cells)) {
        currentStage = cells.first;
        rows.add(
          _PlanRow(
            stage: currentStage,
            task: cells.length >= 3 ? cells[1] : cells.join(' '),
            note: cells.length >= 3 ? cells.skip(2).join(' · ') : '阶段目标',
          ),
        );
        if (rows.length >= 12) break;
        continue;
      }

      final cleaned = _cleanPlanText(line);
      if (cleaned.isEmpty) continue;
      if (_looksLikePlanStage(cleaned)) {
        currentStage = cleaned.length > 28 ? cleaned.substring(0, 28) : cleaned;
        rows.add(_PlanRow(stage: currentStage, task: cleaned, note: '阶段目标'));
      } else if (line.startsWith('-') || line.startsWith('•')) {
        rows.add(_PlanRow(stage: currentStage, task: cleaned, note: '执行任务'));
      }
      if (rows.length >= 12) break;
    }
    if (rows.isEmpty) {
      rows.add(const _PlanRow(stage: '计划', task: '查看上方完整计划', note: 'AI 输出'));
    }
    return rows;
  }

  List<String> _extractPlanTableCells(String line) {
    final trimmed = line.trim();
    if (!trimmed.contains('|')) return const [];
    final compact = trimmed.replaceAll(' ', '');
    if (RegExp(r'^\|?[:\-|]+\|?$').hasMatch(compact)) return const [];
    return trimmed
        .split('|')
        .map(_cleanPlanText)
        .where((cell) => cell.isNotEmpty)
        .toList();
  }

  bool _isPlanTableHeader(List<String> cells) {
    final joined = cells.join('');
    return joined.contains('阶段') &&
        joined.contains('任务') &&
        (joined.contains('说明') || joined.contains('目标'));
  }

  bool _looksLikePlanStage(String text) {
    return (text.contains('第') &&
            (text.contains('周') ||
                text.contains('月') ||
                text.contains('阶段'))) ||
        RegExp(r'week\s*\d+', caseSensitive: false).hasMatch(text) ||
        text.contains('战略层') ||
        text.contains('战术层') ||
        text.contains('执行层');
  }

  String _cleanPlanText(String value) {
    return value
        .replaceAll('**', '')
        .replaceAll(RegExp(r'^[#>\-\s•]+'), '')
        .replaceAll(RegExp(r'\s*\|\s*'), ' · ')
        .replaceAll(RegExp(r'( · ){2,}'), ' · ')
        .replaceAll(RegExp(r'^·\s*|\s*·$'), '')
        .trim();
  }

  String _cleanDisplayMarkdown(String value) {
    return value
        .replaceAll('**', '')
        .replaceAllMapped(
          RegExp(r'__([^_]+)__'),
          (match) => match.group(1) ?? '',
        )
        .trim();
  }

  ({String message, List<String> suggestions}) _extractExplicitOptions(
    String aiMessage,
  ) {
    final optionPattern = RegExp(
      r'^\s*\[OPTIONS:\s*([^\]]+)\]\s*$',
      multiLine: true,
    );
    final suggestions = <String>[];
    final displayMessage = aiMessage.replaceAllMapped(optionPattern, (match) {
      final rawOptions = match.group(1) ?? '';
      suggestions.addAll(
        rawOptions
            .split('|')
            .map((option) => option.trim())
            .where((option) => option.isNotEmpty),
      );
      return '';
    }).trim();

    return (
      message: displayMessage.isEmpty ? aiMessage : displayMessage,
      suggestions: suggestions,
    );
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
      final startTime = DateTime.parse(
        _pendingSchedule!['start_time'] as String,
      );
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('日程已添加 ✅')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('添加失败: $e')));
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
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('AI 助手'),
            const SizedBox(width: 6),
            FadeTransition(
              opacity: _pulseAnimation,
              child: Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: AppTheme.success,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
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
        if (hasAction && msg['action'] == 'plan_view') {
          return _buildPlanCard(msg);
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
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: isUser
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isUser
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isUser) ...[
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    size: 16,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.75,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isUser ? AppTheme.chatUserBg : AppTheme.bgCard,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(14),
                      topRight: const Radius.circular(14),
                      bottomLeft: isUser
                          ? const Radius.circular(14)
                          : const Radius.circular(4),
                      bottomRight: isUser
                          ? const Radius.circular(4)
                          : const Radius.circular(14),
                    ),
                    border: isUser
                        ? const Border(
                            left: BorderSide(
                              color: AppTheme.primaryColor,
                              width: 3,
                            ),
                          )
                        : null,
                    boxShadow: isUser ? null : AppTheme.cardShadowLight,
                  ),
                  child: Text(
                    text,
                    style: TextStyle(
                      color: isUser
                          ? AppTheme.textPrimary
                          : AppTheme.textPrimary,
                      fontSize: 14,
                      height: 1.6,
                    ),
                  ),
                ),
              ),
              if (isUser) const SizedBox(width: 8),
            ],
          ),
          // AI option buttons
          if (!isUser && suggestions != null && suggestions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 38, top: 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: suggestions.map((s) {
                  return ActionChip(
                    label: Text(
                      s,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    onPressed: () => _suggestionClicked(s),
                    backgroundColor: AppTheme.bgCard,
                    side: BorderSide(
                      color: AppTheme.primaryColor.withValues(alpha: 0.3),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
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
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              size: 16,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.bgCard,
                borderRadius: BorderRadius.circular(14),
                boxShadow: AppTheme.cardShadowLight,
                border: Border.all(color: AppTheme.borderSubtle, width: 0.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.event_rounded,
                          size: 16,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          data['title'] ?? '日程',
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(
                        Icons.schedule,
                        size: 14,
                        color: AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${data['start_time']}  →  ${data['end_time']}',
                        style: GoogleFonts.jetBrainsMonoTextTheme().bodySmall
                            ?.copyWith(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () =>
                            setState(() => _pendingSchedule = null),
                        child: const Text(
                          '忽略',
                          style: TextStyle(color: AppTheme.textHint),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: _importSchedule,
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('添加到日历'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard(Map<String, dynamic> msg) {
    final text = msg['message'] as String;
    final rows = (msg['planRows'] as List<_PlanRow>?) ?? const <_PlanRow>[];
    return GestureDetector(
      onSecondaryTapDown: (details) => _showPlanContextMenu(details, rows),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                size: 16,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.bgCard,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: AppTheme.cardShadowLight,
                  border: Border.all(color: AppTheme.borderSubtle, width: 0.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            '计划表',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        PopupMenuButton<String>(
                          tooltip: '计划操作',
                          onSelected: (value) {
                            if (value == 'assign') {
                              _openPlanAssignmentPreview(rows);
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                              value: 'assign',
                              child: Row(
                                children: [
                                  Icon(Icons.assignment_turned_in, size: 18),
                                  SizedBox(width: 8),
                                  Text('一键分配任务'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildPlanTable(rows),
                    const SizedBox(height: 18),
                    const Text(
                      '思维导图',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildPlanFlow(rows),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                        onPressed: () => _openPlanAssignmentPreview(rows),
                        icon: const Icon(Icons.assignment_turned_in, size: 16),
                        label: const Text('一键分配任务'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: EdgeInsets.zero,
                      title: const Text('查看原始计划'),
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            text,
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 13,
                              height: 1.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPlanContextMenu(
    TapDownDetails details,
    List<_PlanRow> rows,
  ) async {
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        details.globalPosition.dx,
        details.globalPosition.dy,
        details.globalPosition.dx,
        details.globalPosition.dy,
      ),
      items: const [
        PopupMenuItem(
          value: 'assign',
          child: Row(
            children: [
              Icon(Icons.assignment_turned_in, size: 18),
              SizedBox(width: 8),
              Text('一键分配任务'),
            ],
          ),
        ),
      ],
    );
    if (selected == 'assign') {
      _openPlanAssignmentPreview(rows);
    }
  }

  Widget _buildPlanTable(List<_PlanRow> rows) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.borderSubtle),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          _planTableRow('阶段', '任务', '说明', isHeader: true),
          for (final row in rows) _planTableRow(row.stage, row.task, row.note),
        ],
      ),
    );
  }

  Widget _planTableRow(
    String stage,
    String task,
    String note, {
    bool isHeader = false,
  }) {
    final style = TextStyle(
      color: isHeader ? AppTheme.textPrimary : AppTheme.textSecondary,
      fontSize: isHeader ? 12 : 11,
      fontWeight: isHeader ? FontWeight.w700 : FontWeight.w500,
      height: 1.35,
    );
    return Container(
      decoration: BoxDecoration(
        color: isHeader ? AppTheme.bgInput : Colors.transparent,
        border: const Border(
          bottom: BorderSide(color: AppTheme.borderSubtle, width: 0.5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Text(stage, style: style),
            ),
          ),
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Text(task, style: style),
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Text(note, style: style),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanFlow(List<_PlanRow> rows) {
    final grouped = <String, List<_PlanRow>>{};
    for (final row in rows.take(10)) {
      grouped.putIfAbsent(row.stage, () => <_PlanRow>[]).add(row);
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _mindNode(
            title: '目标计划',
            subtitle: '${rows.length} 个节点',
            icon: Icons.flag_rounded,
            isRoot: true,
          ),
          _mindConnector(width: 28),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: grouped.entries.take(6).map((entry) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _mindNode(
                      title: entry.key,
                      subtitle: '阶段',
                      icon: Icons.account_tree_rounded,
                    ),
                    _mindConnector(width: 22),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: entry.value.take(3).map((row) {
                        return _mindTaskNode(row.task);
                      }).toList(),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _mindConnector({required double width}) {
    return SizedBox(
      width: width,
      child: Center(
        child: Container(
          height: 1.5,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(1),
          ),
        ),
      ),
    );
  }

  Widget _mindNode({
    required String title,
    required String subtitle,
    required IconData icon,
    bool isRoot = false,
  }) {
    return Container(
      width: isRoot ? 118 : 148,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isRoot
            ? AppTheme.primaryColor
            : AppTheme.primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: isRoot ? 0.0 : 0.24),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 16,
            color: isRoot ? Colors.white : AppTheme.primaryColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isRoot ? Colors.white : AppTheme.textPrimary,
                    fontSize: 12,
                    height: 1.25,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: isRoot
                        ? Colors.white.withValues(alpha: 0.78)
                        : AppTheme.textSecondary,
                    fontSize: 10,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _mindTaskNode(String title) {
    return Container(
      width: 190,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: AppTheme.bgInput,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Text(
        title,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 12,
          height: 1.35,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Future<void> _openPlanAssignmentPreview(List<_PlanRow> rows) async {
    if (rows.isEmpty) return;
    final draftTasks = _buildAssignmentDrafts(rows);
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => _PlanAssignmentDialog(drafts: draftTasks),
      );
      if (confirmed == true) {
        await _saveAssignedTasks(draftTasks);
      }
    } finally {
      for (final draft in draftTasks) {
        draft.dispose();
      }
    }
  }

  List<_PlanTaskDraft> _buildAssignmentDrafts(List<_PlanRow> rows) {
    final base = DateTime.now();
    final baseStart = DateTime(base.year, base.month, base.day, 9);
    final drafts = <_PlanTaskDraft>[];
    var lastParentIndex = -1;
    for (var i = 0; i < rows.length && i < 12; i++) {
      final row = rows[i];
      final start = _inferPlanStart(row, i, baseStart);
      // 根据 stage 判断层级：战略层/战术层为父任务，执行层为子任务
      final isChild = row.stage.contains('执行层');
      if (!isChild) {
        lastParentIndex = drafts.length; // 当前任务将成为新父任务
      }
      drafts.add(_PlanTaskDraft(
        title: row.task,
        description: '${row.stage} · ${row.note}',
        start: start,
        end: start.add(const Duration(hours: 1)),
        priority: 'P2',
        parentDraftIndex: isChild && lastParentIndex >= 0 ? lastParentIndex : -1,
      ));
    }
    return drafts;
  }

  DateTime _inferPlanStart(_PlanRow row, int index, DateTime fallbackStart) {
    final text = '${row.stage} ${row.task} ${row.note}';
    final weekMatch = RegExp(r'第\s*(\d+)\s*周').firstMatch(text);
    final dayMatch = RegExp(r'第\s*(\d+)\s*天').firstMatch(text);
    final hourMatch = RegExp(r'(\d{1,2})[:：](\d{2})').firstMatch(text);

    var start = fallbackStart.add(Duration(days: index));
    if (weekMatch != null) {
      final week = int.tryParse(weekMatch.group(1) ?? '') ?? 1;
      start = fallbackStart.add(Duration(days: (week - 1).clamp(0, 52) * 7));
    } else if (dayMatch != null) {
      final day = int.tryParse(dayMatch.group(1) ?? '') ?? 1;
      start = fallbackStart.add(Duration(days: (day - 1).clamp(0, 365)));
    }

    if (hourMatch != null) {
      final hour = int.tryParse(hourMatch.group(1) ?? '') ?? start.hour;
      final minute = int.tryParse(hourMatch.group(2) ?? '') ?? start.minute;
      start = DateTime(
        start.year,
        start.month,
        start.day,
        hour.clamp(0, 23),
        minute.clamp(0, 59),
      );
    }
    return start;
  }

  Future<void> _saveAssignedTasks(List<_PlanTaskDraft> drafts) async {
    await _storage.init();
    var saved = 0;
    // 先保存所有任务，同时记录已创建任务的 ID 映射
    final taskIdMap = <int, String>{}; // draft index -> created task id
    for (var i = 0; i < drafts.length; i++) {
      final draft = drafts[i];
      if (!draft.enabled) continue;
      if (!draft.end.isAfter(draft.start)) continue;
      final parentTaskId = draft.parentDraftIndex >= 0
          ? taskIdMap[draft.parentDraftIndex]
          : null;
      final created = await _storage.createTask(
        userId: _getUserId(),
        title: draft.titleController.text.trim().isEmpty
            ? draft.title
            : draft.titleController.text.trim(),
        description: draft.descriptionController.text.trim().isEmpty
            ? null
            : draft.descriptionController.text.trim(),
        level: draft.parentDraftIndex >= 0 ? 'subtask' : 'task',
        startDate: draft.start,
        endDate: draft.end,
        priority: draft.priority,
        parentTaskId: parentTaskId,
      );
      taskIdMap[i] = created.id;
      saved++;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('已分配 $saved 个任务')));
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(left: 54, bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(14),
          boxShadow: AppTheme.cardShadowLight,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
            3,
            (i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: _TypingDot(index: i),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    const actions = [
      ('拆解目标', Icons.auto_fix_high_rounded, '我想拆解一个长期目标，帮我规划一下'),
      ('安排日程', Icons.event_rounded, '我想安排一个日程'),
      ('今日建议', Icons.lightbulb_outline_rounded, '给我今天的建议'),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              '快捷操作',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: actions.map((a) {
              return ActionChip(
                avatar: Icon(a.$2, size: 16, color: AppTheme.primaryColor),
                label: Text(
                  a.$1,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textPrimary,
                  ),
                ),
                onPressed: () => _quickAction(a.$3),
                backgroundColor: AppTheme.bgCard,
                side: BorderSide(color: AppTheme.borderSubtle, width: 0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 6),
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
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        border: const Border(
          top: BorderSide(color: AppTheme.borderSubtle, width: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Mic button
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: _isListening
                  ? AppTheme.error.withValues(alpha: 0.1)
                  : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(
                _isListening ? Icons.mic : Icons.mic_outlined,
                color: _isListening ? AppTheme.error : AppTheme.textHint,
                size: 22,
              ),
              onPressed: _startListening,
            ),
          ),
          const SizedBox(width: 4),
          // Input field
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.bgInput,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.borderSubtle, width: 0.5),
              ),
              child: TextField(
                controller: _messageController,
                onSubmitted: (_) => _sendMessage(),
                textInputAction: TextInputAction.send,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: '输入目标或日程...',
                  hintStyle: TextStyle(color: AppTheme.textHint),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  isDense: true,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Send button
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              shape: BoxShape.circle,
              boxShadow: AppTheme.buttonShadow,
            ),
            child: IconButton(
              icon: const Icon(
                Icons.send_rounded,
                size: 16,
                color: Colors.white,
              ),
              onPressed: _sendMessage,
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingDot extends StatefulWidget {
  final int index;
  const _TypingDot({required this.index});

  @override
  State<_TypingDot> createState() => _TypingDotState();
}

class _TypingDotState extends State<_TypingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _animation = Tween<double>(
      begin: 0.4,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    Future.delayed(Duration(milliseconds: widget.index * 200), () {
      if (mounted) _controller.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Container(
        width: 7,
        height: 7,
        decoration: const BoxDecoration(
          color: AppTheme.textHint,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _PlanRow {
  final String stage;
  final String task;
  final String note;

  const _PlanRow({required this.stage, required this.task, required this.note});
}

class _PlanTaskDraft {
  final String title;
  final String description;
  final TextEditingController titleController;
  final TextEditingController descriptionController;
  DateTime start;
  DateTime end;
  String priority;
  bool enabled = true;
  /// -1 = top-level (parent task), >=0 = index of the parent draft in the list
  final int parentDraftIndex;

  _PlanTaskDraft({
    required this.title,
    required this.description,
    required this.start,
    required this.end,
    required this.priority,
    this.parentDraftIndex = -1,
  }) : titleController = TextEditingController(text: title),
       descriptionController = TextEditingController(text: description);

  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
  }
}

class _PlanAssignmentDialog extends StatefulWidget {
  final List<_PlanTaskDraft> drafts;

  const _PlanAssignmentDialog({required this.drafts});

  @override
  State<_PlanAssignmentDialog> createState() => _PlanAssignmentDialogState();
}

class _PlanAssignmentDialogState extends State<_PlanAssignmentDialog> {
  Future<void> _pickDate(_PlanTaskDraft draft, bool isStart) async {
    final source = isStart ? draft.start : draft.end;
    final picked = await showDatePicker(
      context: context,
      initialDate: source,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked == null || !mounted) return;
    setState(() {
      final time = TimeOfDay.fromDateTime(source);
      final next = DateTime(
        picked.year,
        picked.month,
        picked.day,
        time.hour,
        time.minute,
      );
      if (isStart) {
        final delta = draft.end.difference(draft.start);
        draft.start = next;
        draft.end = next.add(
          delta.isNegative ? const Duration(hours: 1) : delta,
        );
      } else {
        draft.end = next;
      }
    });
  }

  Future<void> _pickTime(_PlanTaskDraft draft, bool isStart) async {
    final source = isStart ? draft.start : draft.end;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(source),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (picked == null || !mounted) return;
    setState(() {
      final next = DateTime(
        source.year,
        source.month,
        source.day,
        picked.hour,
        picked.minute,
      );
      if (isStart) {
        final delta = draft.end.difference(draft.start);
        draft.start = next;
        draft.end = next.add(
          delta.isNegative ? const Duration(hours: 1) : delta,
        );
      } else {
        draft.end = next;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = widget.drafts.where((draft) => draft.enabled).length;
    return AlertDialog(
      title: const Text('一键分配任务'),
      content: SizedBox(
        width: 720,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '分配前可以调整标题、说明、开始/结束日期时间。',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 520,
              child: ListView.separated(
                itemCount: widget.drafts.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final draft = widget.drafts[index];
                  return _draftTile(draft, index);
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('取消'),
        ),
        FilledButton.icon(
          onPressed: selectedCount == 0
              ? null
              : () => Navigator.pop(context, true),
          icon: const Icon(Icons.assignment_turned_in, size: 18),
          label: Text('创建 $selectedCount 个任务'),
          style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryColor),
        ),
      ],
    );
  }

  Widget _draftTile(_PlanTaskDraft draft, int index) {
    final invalid = !draft.end.isAfter(draft.start);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: draft.enabled ? AppTheme.bgCard : AppTheme.bgInput,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: invalid ? AppTheme.error : AppTheme.borderSubtle,
        ),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: draft.enabled,
                onChanged: (value) {
                  setState(() => draft.enabled = value ?? false);
                },
              ),
              Expanded(
                child: TextField(
                  controller: draft.titleController,
                  decoration: InputDecoration(labelText: '任务 ${index + 1}'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: draft.descriptionController,
            decoration: const InputDecoration(labelText: '说明'),
            maxLines: 2,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _dateTimeButton(
                  label: '开始',
                  value: draft.start,
                  onDate: () => _pickDate(draft, true),
                  onTime: () => _pickTime(draft, true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _dateTimeButton(
                  label: '结束',
                  value: draft.end,
                  onDate: () => _pickDate(draft, false),
                  onTime: () => _pickTime(draft, false),
                ),
              ),
            ],
          ),
          if (invalid) ...[
            const SizedBox(height: 8),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '结束时间必须晚于开始时间',
                style: TextStyle(color: AppTheme.error, fontSize: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _dateTimeButton({
    required String label,
    required DateTime value,
    required VoidCallback onDate,
    required VoidCallback onTime,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgInput,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextButton.icon(
              onPressed: onDate,
              icon: const Icon(Icons.calendar_today, size: 16),
              label: Text('$label ${_dateLabel(value)}'),
            ),
          ),
          TextButton(onPressed: onTime, child: Text(_timeLabel(value))),
        ],
      ),
    );
  }

  String _dateLabel(DateTime date) =>
      '${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  String _timeLabel(DateTime date) =>
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}
