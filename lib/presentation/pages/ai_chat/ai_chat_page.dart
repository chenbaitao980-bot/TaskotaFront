import 'dart:convert';
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

  void _addMessage({
    required bool isUser,
    required String message,
    String? rawMessage,
  }) {
    setState(() {
      _messages.add({
        'isUser': isUser,
        'message': message,
        'rawMessage': rawMessage ?? message,
        'time': DateTime.now(),
      });
    });
    _scrollToBottom();
  }

  Future<void> _callAI(String userMessage) async {
    setState(() => _isTyping = true);
    try {
      // 先判断是否是直接日程（如"明天下午3点开会"）
      final parsedSchedule = await _aiService.parseSchedule(userMessage);
      final isDirectSchedule =
          parsedSchedule != null && parsedSchedule['type'] == 'schedule';

      if (isDirectSchedule) {
        // 直接日程
        setState(() => _pendingSchedule = parsedSchedule);
        _addMessage(
          isUser: false,
          message: '识别到日程：${parsedSchedule!['title']}',
          rawMessage: json.encode(parsedSchedule),
        );
        setState(() {
          _messages.last['action'] = 'schedule_confirm';
          _messages.last['scheduleData'] = parsedSchedule;
        });
        return;
      }

      // 非直接日程 → 走引导式对话（AI 会返回 time_range_request 让用户选时间）
      await _handleNormalChat(userMessage);
    } catch (e) {
      _addMessage(isUser: false, message: '抱歉，AI 服务暂时不可用，请检查网络后重试。');
    } finally {
      if (mounted) setState(() => _isTyping = false);
    }
  }

  /// 新流程：有明确时间范围的规划请求
  /// 先查已有日程 → 计算空闲时段 → 带约束的规划
  /// 引导式对话
  Future<void> _handleNormalChat(String userMessage) async {
    // 话题漂移检测
    final topicDrift = _detectTopicDrift(userMessage);
    final history = topicDrift ? <Map<String, String>>[] : _buildHistory();

    final profile = _storage.getExplicitProfile();
    final implicit = _storage.getImplicitProfile();
    final userProfile = <String, dynamic>{};
    if (profile != null) userProfile.addAll(profile);
    if (implicit != null) userProfile.addAll(implicit);
    userProfile['completionRate'] = implicit?['avgTaskCompletionRate'] ?? 0.0;

    final result = await _aiService.chat(
      userMessage: userMessage,
      history: history,
      userProfile: userProfile,
      topicSwitchDetected: topicDrift,
    );
    // AI 以 JSON 格式返回 {"type": "...", "message": "...", "options": ["...", "..."]}
    final rawMessage = json.encode(result);
    final aiMessage = result['message'] as String? ?? '';
    final messageType = result['type'] as String? ?? 'normal';
    final explicitSuggestions =
        (result['options'] as List<dynamic>?)?.whereType<String>().toList() ??
        <String>[];
    final displayMessage = _cleanDisplayMarkdown(aiMessage);
    final suggestions = _resolveSuggestions(explicitSuggestions, displayMessage);

    // 处理特殊类型消息
    if (messageType == 'time_range_request') {
      _handleTimeRangeRequest(displayMessage, suggestions);
      return;
    }
    if (messageType == 'topic_switch_confirm') {
      _handleTopicSwitchConfirm(displayMessage, suggestions);
      return;
    }

    // 存储原始 JSON 回复
    _addMessage(isUser: false, message: displayMessage, rawMessage: rawMessage);

    final trimmed = displayMessage.trim();
    final isPlan = _looksLikeFinalPlan(trimmed);
    if (isPlan) {
      setState(() {
        _messages.last['action'] = 'plan_view';
        _messages.last['planRows'] = _extractEditablePlanRows(trimmed);
        _messages.last['planExtras'] = _extractPlanExtras(trimmed);
        if (suggestions.isNotEmpty) {
          _messages.last['suggestions'] = suggestions;
        }
      });
    } else if (suggestions.isNotEmpty) {
      setState(() {
        _messages.last['suggestions'] = suggestions;
      });
    }

    // 只有未检测为 plan_view 时才尝试 parseSchedule
    if (!isPlan) {
      final parsed = await _aiService.parseSchedule(userMessage);
      if (parsed != null && parsed['type'] == 'schedule') {
        setState(() => _pendingSchedule = parsed);
        _messages.last['action'] = 'schedule_confirm';
        _messages.last['scheduleData'] = parsed;
        setState(() {});
      }
    }
  }

  /// 处理时间范围请求：弹出选择框让用户选择时间范围
  void _handleTimeRangeRequest(String message, List<String> suggestions) {
    _addMessage(
      isUser: false,
      message: message,
      rawMessage: json.encode({'type': 'time_range_request', 'message': message, 'options': suggestions}),
    );
    if (suggestions.isNotEmpty) {
      setState(() {
        _messages.last['suggestions'] = suggestions;
        _messages.last['action'] = 'time_range_request';
      });
    }
    // 等当前帧渲染完成后弹出日期选择器
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _openTimeRangePicker();
    });
  }

  /// 处理话题切换确认：弹出确认对话框
  void _handleTopicSwitchConfirm(String message, List<String> suggestions) {
    _addMessage(
      isUser: false,
      message: message,
      rawMessage: json.encode({'type': 'topic_switch_confirm', 'message': message, 'options': suggestions}),
    );
    if (suggestions.isNotEmpty) {
      setState(() {
        _messages.last['suggestions'] = suggestions;
        _messages.last['action'] = 'topic_switch_confirm';
      });
    }
  }

  /// 清空上下文历史
  void _clearContext() {
    showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空上下文'),
        content: const Text('确定要清空所有对话历史吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('清空'),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed == true) {
        setState(() {
          _messages.clear();
          _messages.add({
            'isUser': false,
            'message': '上下文已清空。我是你的 AI 日程管家，有什么可以帮你的吗？',
            'time': DateTime.now(),
          });
        });
      }
    });
  }

  List<String> _resolveSuggestions(
    List<String> explicitSuggestions,
    String message,
  ) {
    final cleaned = <String>[];
    for (final suggestion in explicitSuggestions) {
      final text = suggestion.trim();
      if (text.isEmpty || cleaned.contains(text)) continue;
      cleaned.add(text);
      if (cleaned.length >= 4) break;
    }
    if (cleaned.isNotEmpty) return cleaned;
    if (!_looksLikeQuestion(message)) return const [];
    return _fallbackSuggestionsForQuestion(message);
  }

  List<String> _fallbackSuggestionsForQuestion(String message) {
    final text = message.toLowerCase();
    if (_containsAny(text, ['调整', '修改', '怎么样', '可以吗', '确认'])) {
      return const ['没问题继续', '调整一下', '换个方案'];
    }
    if (_containsAny(text, ['水平', '基础', '了解', '经验', '会不会'])) {
      return const ['完全零基础', '有一点基础', '已经熟悉'];
    }
    if (_containsAny(text, ['时间', '多久', '每天', '每周', '频率'])) {
      return const ['每天30分钟', '每天1小时', '每周3次'];
    }
    if (_containsAny(text, ['目标', '效果', '达到', '希望', '结果'])) {
      return const ['掌握基础', '完成实战', '系统提升'];
    }
    if (_containsAny(text, ['日期', '截止', '什么时候', '哪天'])) {
      return const ['一周内', '一个月内', '暂不限制'];
    }

    final userTurns = _messages.where((m) => m['isUser'] == true).length;
    if (userTurns <= 1) return const ['完全零基础', '有一点基础', '已经熟悉'];
    if (userTurns == 2) return const ['每天30分钟', '每天1小时', '每周3次'];
    if (userTurns == 3) return const ['掌握基础', '完成实战', '系统提升'];
    return const ['没问题继续', '调整一下', '换个方案'];
  }

  bool _containsAny(String text, List<String> keywords) {
    return keywords.any(text.contains);
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
    if (message.contains('[TABLE_BEGIN]') && message.contains('[TABLE_END]')) {
      return true;
    }
    if (_looksLikePlanContent(message)) return true;
    final hasPlanWords =
        message.contains('第1周') ||
        message.contains('第 1 周') ||
        message.contains('计划') ||
        message.contains('里程碑') ||
        message.contains('执行层') ||
        message.contains('战术层') ||
        message.contains('训练');
    final hasMultipleSteps =
        RegExp(
          r'(第\s*\d+\s*[周月天]|week\s*\d+|day\s*\d+)',
          caseSensitive: false,
        ).allMatches(message).length >=
        2;
    // 额外检测：日期+活动模式（如"周一：跑步"、"5月26日 09:00"）
    final hasDateActivity = RegExp(
      r'(周一|周二|周三|周四|周五|周六|周日|星期[一二三四五六日]).*\S+',
    ).hasMatch(message) &&
        RegExp(r'[\u4e00-\u9fff]+').allMatches(message).length >= 10;
    // 检测时间安排模式：多条带日期/时间的条目
    final hasTimeEntries = RegExp(
      r'(0?\d|1\d|2[0-3])[:：][0-5]\d',
    ).allMatches(message).length >= 2;
    return (hasPlanWords && hasMultipleSteps) ||
        (hasDateActivity && hasTimeEntries);
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
            r'^(\d+[\.\、\)]|第\s*\d+|week\s*\d+|day\s*\d+)',
            caseSensitive: false,
          ).hasMatch(line),
        )
        .length;
    final bulletRows = lines
        .where((line) => line.startsWith('-') || line.startsWith('*') || line.startsWith('•'))
        .length;
    final hasPlanWords =
        message.contains('计划') ||
        message.contains('阶段') ||
        message.contains('任务') ||
        message.contains('流程') ||
        message.contains('里程碑') ||
        message.contains('训练') ||
        message.toLowerCase().contains('plan') ||
        message.toLowerCase().contains('schedule') ||
        message.toLowerCase().contains('activity');

    return (tableRows >= 1 && hasPlanWords) ||
        (numberedRows >= 2 && hasPlanWords) ||
        (bulletRows >= 3 && hasPlanWords) ||
        // 检测：星期X：内容 模式（如"周一：跑步 30分钟"）
        (RegExp(r'(周一|周二|周三|周四|周五|周六|周日|星期[一二三四五六日])[:：]').allMatches(message).length >= 2);
  }

  // ignore: unused_element
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
      rows.add(_PlanRow(stage: '计划', task: '查看上方完整计划', note: 'AI 输出'));
    }
    return rows;
  }

  List<_PlanRow> _extractEditablePlanRows(String message) {
    final tableMatch = RegExp(
      r'\[TABLE_BEGIN\]\n(.*?)\[TABLE_END\]',
      dotAll: true,
    ).firstMatch(message);
    final source = tableMatch?.group(1) ?? message;
    final rows = <_PlanRow>[];
    var currentStage = '计划';

    for (final line in source.split('\n')) {
      final cells = _extractPlanTableCells(line);
      if (cells.length >= 2) {
        if (_isPlanTableHeader(cells)) continue;
        currentStage = cells.first;
        rows.add(_editablePlanRowFromCells(cells, rows.length));
        continue;
      }

      final cleaned = _cleanPlanText(line);
      if (cleaned.isEmpty) continue;
      if (_looksLikePlanStage(cleaned)) {
        currentStage = cleaned.length > 28 ? cleaned.substring(0, 28) : cleaned;
      } else if (line.trimLeft().startsWith('-') ||
          line.trimLeft().startsWith('*') ||
          line.trimLeft().startsWith('•')) {
        final start = _defaultPlanStart(rows.length);
        rows.add(
          _PlanRow(
            stage: currentStage,
            task: cleaned,
            note: cleaned,
            start: start,
            end: start.add(const Duration(hours: 1)),
          ),
        );
      } else if (_isWeekdayActivity(cleaned)) {
        // 处理"周一：跑步 30分钟"、"周二 09:00 游泳"等非表格日程描述
        final start = _defaultPlanStart(rows.length);
        rows.add(
          _PlanRow(
            stage: currentStage,
            task: cleaned,
            note: cleaned,
            start: start,
            end: start.add(const Duration(hours: 1)),
          ),
        );
      }
    }

    if (rows.isNotEmpty) return _normalizePlanDates(rows);
    final start = _defaultPlanStart(0);
    return [
      _PlanRow(
        stage: '计划',
        task: '查看上方完整计划',
        note: 'AI 输出',
        start: start,
        end: start.add(const Duration(hours: 1)),
      ),
    ];
  }

  _PlanRow _editablePlanRowFromCells(List<String> cells, int index) {
    final dateLabel = cells.isNotEmpty ? cells[0] : '计划';
    final subject = cells.length >= 2 ? cells[1] : '任务';
    final content = cells.length >= 3 ? cells[2] : cells.skip(1).join(' · ');
    final start = _parsePlanDateTime(cells, index, preferEnd: false);
    final parsedEnd = _parsePlanDateTime(cells, index, preferEnd: true);
    final end = parsedEnd.isAfter(start)
        ? parsedEnd
        : start.add(const Duration(hours: 1));

    return _PlanRow(
      stage: dateLabel,
      task: _isHeaderLike(subject) ? content : subject,
      note: content,
      start: start,
      end: end,
    );
  }

  bool _isHeaderLike(String value) {
    final compact = value.replaceAll(' ', '');
    return compact == '主题' ||
        compact == '日期' ||
        compact == '训练内容' ||
        compact == '任务';
  }

  DateTime _defaultPlanStart(int index) {
    final now = DateTime.now();
    final slots = DateTime.sunday - now.weekday + 1; // 本周剩余天数+1（含今天）
    if (index < slots) {
      // 本周容量内：正常逐天递进
      return DateTime(now.year, now.month, now.day, 9).add(Duration(days: index));
    }
    // 超出本周容量：在最后一天错峰分配（9→10→11→...）
    final overflowHour = 9 + (index - slots + 1);
    final lastDay = DateTime.sunday - now.weekday;
    return DateTime(now.year, now.month, now.day + lastDay, overflowHour.clamp(9, 23));
  }

  DateTime _parsePlanDateTime(
    List<String> cells,
    int index, {
    required bool preferEnd,
  }) {
    final fallback = _defaultPlanStart(index);
    final text = cells.join(' ');
    final date = _parsePlanDate(text, fallback);
    final timeMatches = RegExp(
      r'(\d{1,2})[:：](\d{2})',
    ).allMatches(text).toList();
    final timeMatch = timeMatches.isEmpty
        ? null
        : timeMatches[(preferEnd && timeMatches.length > 1) ? 1 : 0];
    final hour =
        int.tryParse(timeMatch?.group(1) ?? '') ??
        (preferEnd ? fallback.hour + 1 : fallback.hour);
    final minute = int.tryParse(timeMatch?.group(2) ?? '') ?? fallback.minute;
    final result = DateTime(
      date.year,
      date.month,
      date.day,
      hour.clamp(0, 23),
      minute.clamp(0, 59),
    );
    // 如果结果超出本周，回退到 _defaultPlanStart（自带错峰分布）
    final now = DateTime.now();
    final daysUntilSunday = DateTime.sunday - now.weekday;
    final thisSunday = DateTime(now.year, now.month, now.day + daysUntilSunday, 23, 59);
    return result.isAfter(thisSunday) ? fallback : result;
  }

  DateTime _parsePlanDate(String text, DateTime fallback) {
    final md = RegExp(r'(\d{1,2})[/-](\d{1,2})').firstMatch(text);
    if (md != null) {
      final month = int.tryParse(md.group(1) ?? '') ?? fallback.month;
      final day = int.tryParse(md.group(2) ?? '') ?? fallback.day;
      return DateTime(fallback.year, month.clamp(1, 12), day.clamp(1, 31));
    }
    final dayIndex = _weekdayIndex(text);
    if (dayIndex >= 0) {
      final base = DateTime(fallback.year, fallback.month, fallback.day);
      return base.add(Duration(days: dayIndex));
    }
    return fallback;
  }

  int _weekdayIndex(String text) {
    const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    for (var i = 0; i < weekdays.length; i++) {
      if (text.contains(weekdays[i])) return i;
    }
    return -1;
  }

  _PlanExtras _extractPlanExtras(String message) {
    final materials = <String>[];
    final keyPoints = <String>[];
    var progress = 0.0;
    var section = '';

    for (final rawLine in message.split('\n')) {
      final line = _cleanPlanText(rawLine);
      if (line.isEmpty) continue;
      if (_containsAny(line, ['装备', '材料', '准备清单', '需要准备', '清单'])) {
        section = 'materials';
        final inline = _afterSectionTitle(line);
        if (inline.isNotEmpty) materials.addAll(_splitInlineItems(inline));
        continue;
      }
      if (_containsAny(line, ['要点', '重点', '核心', '零基础'])) {
        section = 'keyPoints';
        final inline = _afterSectionTitle(line);
        if (inline.isNotEmpty) keyPoints.addAll(_splitInlineItems(inline));
        continue;
      }
      if (_containsAny(line, ['进度', 'progress'])) {
        final percent = RegExp(r'(\d{1,3})\s*%').firstMatch(line);
        if (percent != null) {
          progress = (int.parse(percent.group(1)!).clamp(0, 100)) / 100;
        } else {
          progress = progress == 0 ? 0.15 : progress;
        }
      }

      final isListItem =
          rawLine.trimLeft().startsWith('-') ||
          rawLine.trimLeft().startsWith('*') ||
          rawLine.trimLeft().startsWith('•');
      if (!isListItem) continue;
      if (section == 'materials' && materials.length < 6) {
        materials.add(line);
      } else if (section == 'keyPoints' && keyPoints.length < 4) {
        keyPoints.add(line);
      }
    }

    return _PlanExtras(
      materials: _uniqueStrings(materials).take(6).toList(),
      keyPoints: _uniqueStrings(keyPoints).take(4).toList(),
      progress: progress,
    );
  }

  String _afterSectionTitle(String line) {
    final parts = line.split(RegExp(r'[:：]'));
    if (parts.length < 2) return '';
    return parts.skip(1).join('：').trim();
  }

  List<String> _splitInlineItems(String value) {
    return value
        .split(RegExp(r'[、，,；;+/＋]'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  List<String> _uniqueStrings(List<String> values) {
    final result = <String>[];
    for (final value in values) {
      if (value.isEmpty || result.contains(value)) continue;
      result.add(value);
    }
    return result;
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
    if (joined.contains('日期') &&
        joined.contains('主题') &&
        joined.contains('训练内容')) {
      return true;
    }
    if (joined.contains('开始') && joined.contains('结束')) return true;
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

  /// 检测星期+活动模式：如"周一：跑步 30分钟"、"周二09：00游泳"
  bool _isWeekdayActivity(String text) {
    return RegExp(r'^(周[一二三四五六日]|星期[一二三四五六日])').hasMatch(text) &&
        text.length >= 4;
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

  void _suggestionClicked(String text) {
    _addMessage(isUser: true, message: text);
    _callAI(text);
  }

  /// 处理话题切换确认选择
  void _onTopicSwitchSelected(String choice) {
    if (choice.contains('开启新对话')) {
      // 清空历史，保留当前用户消息
      final userMessages = _messages.where((m) => m['isUser'] == true).toList();
      final lastUserMessage = userMessages.isNotEmpty ? userMessages.last['message'] as String? : null;
      setState(() {
        _messages.clear();
        _messages.add({
          'isUser': false,
          'message': '已开启新对话。我是你的 AI 日程管家，有什么可以帮你的吗？',
          'time': DateTime.now(),
        });
      });
      if (lastUserMessage != null) {
        // 重新发送最后一条用户消息作为新对话的开始
        Future.delayed(const Duration(milliseconds: 300), () {
          _addMessage(isUser: true, message: lastUserMessage);
          _callAI(lastUserMessage);
        });
      }
    } else {
      // 继续当前话题，发送用户选择给 AI
      _addMessage(isUser: true, message: choice);
      _callAI(choice);
    }
  }

  /// 话题漂移检测：判断用户是否切换了话题
  bool _detectTopicDrift(String currentMessage) {
    // 极短消息（确认/回应）不触发话题检测
    if (currentMessage.trim().length < 4) return false;
    // 常见的回应/确认文字不触发话题检测
    if (_isResponseText(currentMessage)) return false;

    // 从后向前取最近 3 条用户消息
    final recentMessages = <String>[];
    for (var i = _messages.length - 1; i >= 0; i--) {
      if (_messages[i]['isUser'] == true) {
        recentMessages.add(_messages[i]['message'] as String);
        if (recentMessages.length >= 3) break;
      }
    }
    if (recentMessages.isEmpty) return false;

    // 提取当前消息的关键词
    final currentKeywords = _extractKeywords(currentMessage);
    if (currentKeywords.isEmpty) return false;

    // 与最近 N 条消息逐一比对关键词重叠
    for (final recent in recentMessages) {
      final recentKeywords = _extractKeywords(recent);
      final overlap = currentKeywords.intersection(recentKeywords);
      if (overlap.isNotEmpty) return false; // 有重叠 → 话题延续
    }

    // 所有最近消息都无关键词重叠 → 话题漂移
    return true;
  }

  /// 从中文字符串中提取有意义的主题关键词
  Set<String> _extractKeywords(String text) {
    const stopWords = <String>{
      '的', '了', '是', '在', '我', '你', '他', '她', '它', '们',
      '这', '那', '什么', '怎么', '为什么', '吗', '呢', '吧', '啊',
      '哦', '嗯', '哈', '呀', '嘛', '个', '有', '不', '就', '都',
      '也', '很', '要', '会', '能', '去', '想', '和', '与', '或',
      '但', '而', '所以', '因为', '如果', '虽然', '然后', '之后',
      '可以', '没有', '已经', '还', '来', '让', '给', '对', '到',
      '把', '被', '从', '这个', '那个',
      '这些', '那些', '一点', '一下', '一个', '一种', '一些', '一样',
    };
    // 上下文时间词：在话题漂移检测中无区分价值
    const contextWords = <String>{
      '这周', '下周', '上周', '本周', '今天', '明天', '昨天', '后天',
      '今天早上', '今天下午', '今天晚上', '明天早上', '明天下午', '明天晚上',
      '这周日', '下周一', '下周二', '下周三', '下周四', '下周五', '下周六', '下周日',
      '周一', '周二', '周三', '周四', '周五', '周六', '周日',
      '星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日',
      '每天', '每周', '每月', '上周一', '上周二', '上周三', '上周四', '上周五', '上周六', '上周日',
    };
    const allFilter = {...stopWords, ...contextWords};

    // 按标点/空格分割，提取有意义的关键词
    final tokens = text
        .split(RegExp(r'[\s,，。.、！!？?；;：:""""（）()【】\[\]{}《》<>/\\|@#\$%^&*_—\-+=\n\r\t]+'))
        .map((t) => t.trim())
        .where((t) => t.length >= 2 && !allFilter.contains(t))
        .toSet();
    if (tokens.isNotEmpty) return tokens;

    // 如果 split 后无结果（纯英文场景），降级用 2-gram
    final chars = text.runes.toList();
    final bigrams = <String>{};
    for (var i = 0; i < chars.length - 1; i++) {
      final bigram = String.fromCharCodes([chars[i], chars[i + 1]]);
      if (!allFilter.contains(bigram)) bigrams.add(bigram);
    }
    return bigrams;
  }

  /// 判断是否为回应/确认类文字（不触发话题漂移）
  bool _isResponseText(String text) {
    final trimmed = text.trim();
    // 简洁肯定/否定回应
    if (const {'好的', '行', '可以', '嗯', '哦', '好', 'OK', 'ok', 'yes', 'no', '不用', '不要'}.contains(trimmed.toLowerCase())) return true;
    // 以常见回应词开头
    if (RegExp(r'^(没问题|调整|换个|继续|可以|不用|不要|好的|行[\s,，。]|是的|对的|明白|知道|收到|算了|放弃|不做了|先这样|就这样|先放着|以后再说|等等|稍等|等一下)').hasMatch(trimmed)) return true;
    return false;
  }

  /// 构建发送给 AI 的对话历史
  List<Map<String, String>> _buildHistory() {
    final history = <Map<String, String>>[];
    final start = _messages.length > 10 ? _messages.length - 10 : 0;
    for (var i = start; i < _messages.length - 1; i++) {
      final m = _messages[i];
      if (m['action'] != null) continue;
      // 使用原始回复（含 [OPTIONS:]）发送给 AI，让 AI 在对话历史中看到自己的格式范例
      final content = (m['rawMessage'] as String?) ?? (m['message'] as String);
      if (m['isUser'] as bool) {
        history.add({'role': 'user', 'content': m['message'] as String});
      } else {
        history.add({'role': 'assistant', 'content': content});
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
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            tooltip: '清空上下文',
            onPressed: _clearContext,
          ),
        ],
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
        if (hasAction && msg['action'] == 'time_range_request') {
          return _buildTimeRangeRequestCard(msg);
        }
        if (hasAction && msg['action'] == 'topic_switch_confirm') {
          return _buildTopicSwitchConfirmCard(msg);
        }

        return _buildBubble(msg);
      },
    );
  }

  /// 构建时间范围请求卡片
  Widget _buildTimeRangeRequestCard(Map<String, dynamic> msg) {
    final text = msg['message'] as String;

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
                          Icons.schedule_rounded,
                          size: 16,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '时间范围选择',
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
                  Text(
                    text,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => _openTimeRangePicker(),
                    icon: const Icon(Icons.date_range, size: 16),
                    label: const Text('选择日期范围'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryColor,
                      side: const BorderSide(color: AppTheme.primaryColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openTimeRangePicker() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 7)),
      lastDate: now.add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(
        start: now,
        end: now.add(const Duration(days: 7)),
      ),
      helpText: '选择目标完成的时间范围',
      cancelText: '取消',
      confirmText: '确认',
    );
    if (picked != null) {
      final rangeStr = '${picked.start.year}-${picked.start.month.toString().padLeft(2, '0')}-${picked.start.day.toString().padLeft(2, '0')} 到 '
          '${picked.end.year}-${picked.end.month.toString().padLeft(2, '0')}-${picked.end.day.toString().padLeft(2, '0')}';
      _addMessage(isUser: true, message: rangeStr);
      _callAI('我选择的时间范围是：$rangeStr');
    }
  }

  /// 构建话题切换确认卡片
  Widget _buildTopicSwitchConfirmCard(Map<String, dynamic> msg) {
    final text = msg['message'] as String;
    final suggestions = msg['suggestions'] as List<String>?;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppTheme.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.swap_horiz_rounded,
              size: 16,
              color: AppTheme.warning,
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
                border: Border.all(color: AppTheme.warning.withValues(alpha: 0.3), width: 0.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppTheme.warning.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.warning_amber_rounded,
                          size: 16,
                          color: AppTheme.warning,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '话题切换确认',
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
                  Text(
                    text,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                      height: 1.6,
                    ),
                  ),
                  if (suggestions != null && suggestions.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: suggestions.map((s) {
                        final isNewChat = s.contains('开启新对话');
                        return ActionChip(
                          label: Text(
                            s,
                            style: TextStyle(
                              fontSize: 12,
                              color: isNewChat ? AppTheme.error : AppTheme.primaryColor,
                            ),
                          ),
                          onPressed: () => _onTopicSwitchSelected(s),
                          backgroundColor: AppTheme.bgCard,
                          side: BorderSide(
                            color: isNewChat 
                                ? AppTheme.error.withValues(alpha: 0.3)
                                : AppTheme.primaryColor.withValues(alpha: 0.3),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
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
          if (!isUser && suggestions != null && suggestions.isNotEmpty)
            _buildSuggestionChips(suggestions, leftPadding: 38),
        ],
      ),
    );
  }

  Widget _buildSuggestionChips(
    List<String> suggestions, {
    double leftPadding = 0,
  }) {
    return Padding(
      padding: EdgeInsets.only(left: leftPadding, top: 8),
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
            onPressed: () {
              // 检查当前消息是否是时间范围请求或话题切换确认
              final lastMsg = _messages.isNotEmpty ? _messages.last : null;
              final action = lastMsg?['action'] as String?;
              if (action == 'time_range_request') {
                _openTimeRangePicker();
              } else if (action == 'topic_switch_confirm') {
                _onTopicSwitchSelected(s);
              } else {
                _suggestionClicked(s);
              }
            },
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
    final extras =
        msg['planExtras'] as _PlanExtras? ??
        const _PlanExtras(materials: [], keyPoints: [], progress: 0);
    final suggestions = msg['suggestions'] as List<String>?;
    final planTablePage = (msg['planTablePage'] as int?) ?? 0;
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
                    _buildPlanTable(rows, planTablePage, (newPage) {
                      setState(() {
                        msg['planTablePage'] = newPage;
                      });
                    }),
                    const SizedBox(height: 18),
                    const Text(
                      '时间线',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildPlanFlow(rows),
                    if (extras.hasContent) ...[
                      const SizedBox(height: 14),
                      _buildPlanExtras(extras),
                    ],
                    if (suggestions != null && suggestions.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _buildSuggestionChips(suggestions),
                    ],
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
                    _buildWBSMindMap(rows),
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

  Widget _buildPlanExtras(_PlanExtras extras) {
    final progress = extras.progress.clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (extras.materials.isNotEmpty)
          _planInfoPanel(
            title: '需要准备清单',
            icon: Icons.inventory_2_outlined,
            children: extras.materials,
          ),
        if (extras.materials.isNotEmpty && extras.keyPoints.isNotEmpty)
          const SizedBox(height: 10),
        if (extras.keyPoints.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppTheme.primaryColor.withValues(alpha: 0.28),
              ),
            ),
            child: Text(
              extras.keyPoints.join(' → '),
              style: const TextStyle(
                color: AppTheme.primaryColor,
                fontSize: 13,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        if (progress > 0) ...[
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 16,
              value: progress,
              backgroundColor: AppTheme.borderSubtle,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 4),
          const Center(
            child: Text(
              '训练进度',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
          ),
        ],
      ],
    );
  }

  Widget _planInfoPanel({
    required String title,
    required IconData icon,
    required List<String> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.bgInput,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppTheme.textSecondary),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final item in children)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                item,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPlanTable(
    List<_PlanRow> rows,
    int page,
    ValueChanged<int> onPageChanged,
  ) {
    const pageSize = 5;
    final totalPages = (rows.length + pageSize - 1) ~/ pageSize;
    final page0 = page.clamp(0, totalPages > 0 ? totalPages - 1 : 0);
    final start = page0 * pageSize;
    final end = (start + pageSize).clamp(0, rows.length);
    final displayRows = rows.sublist(start, end);

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.borderSubtle),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _planTableRow('时间', '主题', '训练内容', isHeader: true),
          for (var i = 0; i < displayRows.length; i++)
            _editablePlanTableRow(displayRows[i], start + i),
          if (totalPages > 1)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left, size: 20),
                    onPressed:
                        page0 > 0 ? () => onPageChanged(page0 - 1) : null,
                    visualDensity: VisualDensity.compact,
                    tooltip: '上一页',
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${page0 + 1} / $totalPages',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, size: 20),
                    onPressed:
                        page0 < totalPages - 1
                            ? () => onPageChanged(page0 + 1)
                            : null,
                    visualDensity: VisualDensity.compact,
                    tooltip: '下一页',
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _editablePlanTableRow(_PlanRow row, int index) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppTheme.borderSubtle, width: 0.5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: _planTimeRow(row),
            ),
          ),
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: TextFormField(
                key: ValueKey('plan-subject-$index-${row.subject}'),
                initialValue: row.subject,
                minLines: 1,
                maxLines: 2,
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                ),
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
                onChanged: (value) => row.subject = value.trim(),
              ),
            ),
          ),
          Expanded(
            flex: 5,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: TextFormField(
                key: ValueKey('plan-content-$index-${row.content}'),
                initialValue: row.content,
                minLines: 1,
                maxLines: 3,
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                ),
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  height: 1.35,
                ),
                onChanged: (value) => row.content = value.trim(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _planTimeButton({
    required String label,
    required DateTime value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: AppTheme.bgInput,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '$label ${_formatPlanDateTime(value)}',
          style: const TextStyle(
            color: AppTheme.primaryColor,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  /// 开始/结束时间合并到同一行展示
  Widget _planTimeRow(_PlanRow row) {
    final startStr = _formatPlanDateTime(row.start);
    final endStr = row.start.day == row.end.day && row.start.month == row.end.month
        ? '${row.end.hour.toString().padLeft(2, '0')}:${row.end.minute.toString().padLeft(2, '0')}'
        : _formatPlanDateTime(row.end);
    return InkWell(
      onTap: () async {
        // 点击时间合并行，先弹出开始时间编辑，然后结束时间编辑
        await _editPlanRowDateTime(row, true);
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: AppTheme.bgInput,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: startStr,
                style: const TextStyle(
                  color: AppTheme.primaryColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const TextSpan(
                text: ' ~ ',
                style: TextStyle(
                  color: AppTheme.textHint,
                  fontSize: 11,
                ),
              ),
              TextSpan(
                text: endStr,
                style: const TextStyle(
                  color: AppTheme.primaryColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Future<void> _editPlanRowDateTime(_PlanRow row, bool isStart) async {
    final source = isStart ? row.start : row.end;
    final date = await showDatePicker(
      context: context,
      initialDate: source,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(source),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (time == null || !mounted) return;
    setState(() {
      final next = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      if (isStart) {
        final delta = row.end.difference(row.start);
        row.start = next;
        row.end = next.add(delta.isNegative ? const Duration(hours: 1) : delta);
      } else {
        row.end = next;
        if (!row.end.isAfter(row.start)) {
          row.end = row.start.add(const Duration(hours: 1));
        }
      }
      row.dateLabel = _formatPlanDate(row.start);
    });
  }

  /// 后处理：将计划行的日期归一化为本周内连续日期
  List<_PlanRow> _normalizePlanDates(List<_PlanRow> rows) {
    if (rows.isEmpty) return rows;
    final now = DateTime.now();
    final daysUntilSunday = DateTime.sunday - now.weekday;
    final thisSunday = DateTime(now.year, now.month, now.day + daysUntilSunday, 23, 59);

    for (var i = 0; i < rows.length; i++) {
      final assignedDay = now.day + i;
      final assignedDate = DateTime(now.year, now.month, assignedDay);

      if (!assignedDate.isAfter(thisSunday)) {
        // 本周内：保留原始时间，只改日期
        rows[i].start = DateTime(
          assignedDate.year, assignedDate.month, assignedDate.day,
          rows[i].start.hour, rows[i].start.minute,
        );
        rows[i].end = DateTime(
          assignedDate.year, assignedDate.month, assignedDate.day,
          rows[i].end.hour, rows[i].end.minute,
        );
      } else {
        // 超出本周：放在本周日，按行错峰（9→10→11→...）
        final overflowHour = 9 + (i - (daysUntilSunday + 1) + 1);
        rows[i].start = DateTime(
          thisSunday.year, thisSunday.month, thisSunday.day,
          overflowHour.clamp(9, 23), 0,
        );
        rows[i].end = rows[i].start.add(const Duration(hours: 1));
      }
    }
    return rows;
  }

  String _formatPlanDateTime(DateTime value) {
    return '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')} '
        '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}';
  }

  String _formatPlanDate(DateTime value) {
    return '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }

  /// 将超出本周日 23:59 的日期截断到本周日 23:59
  // ignore: unused_element
  DateTime _clampToThisWeek(DateTime date) {
    final now = DateTime.now();
    final daysUntilSunday = DateTime.sunday - now.weekday; // sunday=7, weekday mon=1 → 6
    final lastDay = DateTime(now.year, now.month, now.day + daysUntilSunday, 23, 59);
    return date.isAfter(lastDay) ? lastDay : date;
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
    return _buildTimelineView(rows);
  }

  Widget _buildTimelineView(List<_PlanRow> rows) {
    // 按 start 升序排列，同天时按原始索引排序
    final sorted = List<_PlanRow>.from(rows);
    final indices = {for (var i = 0; i < rows.length; i++) rows[i]: i};
    sorted.sort((a, b) {
      final cmp = a.start.compareTo(b.start);
      return cmp != 0 ? cmp : (indices[a] ?? 0).compareTo(indices[b] ?? 0);
    });

    const colors = [
      Color(0xFFE9E7FF),
      Color(0xFFDDF5EC),
      Color(0xFFE3F1FF),
      Color(0xFFFFF1DD),
      Color(0xFFFFE8F0),
      Color(0xFFEAF6DD),
      Color(0xFFFFECE4),
    ];
    const borders = [
      Color(0xFF9B8CFF),
      Color(0xFF59B98E),
      Color(0xFF5D9CE8),
      Color(0xFFE7A145),
      Color(0xFFE86F98),
      Color(0xFF84B55A),
      Color(0xFFFF8B6B),
    ];

    // 固定最大高度，超出垂直滚动（"弯弯绕绕"效果）
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 220),
      child: Scrollbar(
        thumbVisibility: true,
        child: SingleChildScrollView(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < sorted.length; i++)
                _compactTimelineCard(
                  row: sorted[i],
                  background: colors[i % colors.length],
                  border: borders[i % borders.length],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _compactTimelineCard({
    required _PlanRow row,
    required Color background,
    required Color border,
  }) {
    final timeStr = '${row.start.month.toString().padLeft(2, '0')}-'
        '${row.start.day.toString().padLeft(2, '0')}\n'
        '${row.start.hour.toString().padLeft(2, '0')}:'
        '${row.start.minute.toString().padLeft(2, '0')}';
    return Container(
      width: 160,
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: background.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            timeStr,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            row.subject,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }

  /*
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
  */

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
    final drafts = <_PlanTaskDraft>[];
    var lastParentIndex = -1;
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      final start = row.start;
      final end = row.end.isAfter(row.start)
          ? row.end
          : row.start.add(const Duration(hours: 1));
      // 根据 stage 判断层级：战略层/战术层为父任务，执行层为子任务
      final isChild = row.stage.contains('执行层');
      if (!isChild) {
        lastParentIndex = drafts.length; // 当前任务将成为新父任务
      }
      drafts.add(
        _PlanTaskDraft(
          title: _assignmentTitleFor(row),
          description: row.content,
          start: start,
          end: end,
          priority: 'P2',
          parentDraftIndex: isChild && lastParentIndex >= 0
              ? lastParentIndex
              : -1,
        ),
      );
    }
    return drafts;
  }

  String _assignmentTitleFor(_PlanRow row) {
    final subject = row.subject.trim();
    if (subject.isNotEmpty && !_isHeaderLike(subject)) return subject;
    final content = row.content.trim();
    if (content.isNotEmpty && !_isHeaderLike(content)) return content;
    return '计划任务';
  }

  // ignore: unused_element
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
    final conflicts = <String>[];
    final taskIdMap = <int, String>{};
    for (var i = 0; i < drafts.length; i++) {
      final draft = drafts[i];
      if (!draft.enabled) continue;
      if (!draft.end.isAfter(draft.start)) continue;

      // 二次冲突校验：检查该时间段是否已被占用
      if (_storage.detectTimeConflict(draft.start, draft.end)) {
        conflicts.add('"${draft.title}" (${_formatPlanDateTime(draft.start)} ~ ${_formatPlanDateTime(draft.end)})');
        continue;
      }

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

    // 显示结果，包括冲突提示
    String msg = '已分配 $saved 个任务';
    if (conflicts.isNotEmpty) {
      msg += '\n以下 ${conflicts.length} 个任务因时间冲突已跳过：\n${conflicts.join('\n')}';
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg)));
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

  /// 构建 WBS 任务分解思维导图：按 stage 分组，展示树形结构
  Widget _buildWBSMindMap(List<_PlanRow> rows) {
    if (rows.isEmpty) return const SizedBox.shrink();
    final grouped = <String, List<_PlanRow>>{};
    for (final row in rows) {
      grouped.putIfAbsent(row.stage.trim(), () => []).add(row);
    }
    return Container(
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.account_tree_rounded, size: 14, color: AppTheme.primaryColor),
              ),
              const SizedBox(width: 8),
              const Text(
                '任务分解',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...grouped.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppTheme.primaryColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${entry.key}（${entry.value.length} 项）',
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  ...entry.value.map((row) => Padding(
                    padding: const EdgeInsets.only(left: 20, top: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 5),
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: AppTheme.textHint,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            row.subject,
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
                ],
              ),
            );
          }),
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
  String dateLabel;
  String subject;
  String content;
  DateTime start;
  DateTime end;

  _PlanRow({
    required String stage,
    required String task,
    required String note,
    DateTime? start,
    DateTime? end,
  }) : dateLabel = stage,
       subject = task,
       content = note,
       start = start ?? DateTime.now(),
       end = end ?? (start ?? DateTime.now()).add(const Duration(hours: 1));

  String get stage => dateLabel;
  String get task => subject;
  String get note => content;
}

class _PlanExtras {
  final List<String> materials;
  final List<String> keyPoints;
  final double progress;

  const _PlanExtras({
    required this.materials,
    required this.keyPoints,
    required this.progress,
  });

  bool get hasContent =>
      materials.isNotEmpty || keyPoints.isNotEmpty || progress > 0;
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
