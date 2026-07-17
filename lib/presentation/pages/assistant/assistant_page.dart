import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../data/repositories/project_repository.dart';
import '../../../data/repositories/task_repository.dart';
import '../../../models/assistant/assistant_models.dart';
import '../../../services/assistant_chat_service.dart';
import '../../../services/assistant_config_service.dart';
import '../../../services/assistant_tool_service.dart';
import '../../../services/local_storage_service.dart';

class AssistantPage extends StatefulWidget {
  final TaskRepository? taskRepository;
  final ProjectRepository? projectRepository;
  final LocalStorageService storage;

  const AssistantPage({
    super.key,
    required this.storage,
    this.taskRepository,
    this.projectRepository,
  });

  @override
  State<AssistantPage> createState() => _AssistantPageState();
}

class _AssistantPageState extends State<AssistantPage> {
  final _configService = AssistantConfigService();
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final _inputFocusNode = FocusNode();

  AssistantModelConfig _config = const AssistantModelConfig();
  List<AssistantMessage> _messages = [];
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final config = await _configService.loadConfig();
    final messages = await _configService.loadMessages();
    if (!mounted) return;
    setState(() {
      _config = config;
      _messages = messages;
      _loading = false;
    });
    _scrollToBottom();
  }

  Future<void> _send() async {
    final question = _inputController.text.trim();
    if (question.isEmpty || _sending) return;
    final userMessage = AssistantMessage(
      role: 'user',
      content: question,
      createdAt: DateTime.now(),
    );
    setState(() {
      _messages = [..._messages, userMessage];
      _sending = true;
      _inputController.clear();
    });
    await _configService.saveMessages(_messages);
    _scrollToBottom();

    final chatService = AssistantChatService(
      toolService: AssistantToolService(
        taskRepository: widget.taskRepository,
        projectRepository: widget.projectRepository,
        storage: widget.storage,
      ),
    );
    final result = await chatService.send(
      config: _config,
      history: _messages,
      question: question,
    );
    if (!mounted) return;
    setState(() {
      _messages = [..._messages, ...result.messagesToAppend];
      _sending = false;
    });
    await _configService.saveMessages(_messages);
    _scrollToBottom();
    _inputFocusNode.requestFocus();
  }

  Future<void> _openConfig() async {
    final next = await showDialog<AssistantModelConfig>(
      context: context,
      builder: (_) => _AssistantConfigDialog(config: _config),
    );
    if (next == null) return;
    await _configService.saveConfig(next);
    if (!mounted) return;
    setState(() => _config = next);
    showAppSnackBar(context, '助手模型配置已保存');
  }

  Future<void> _clearConversation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空对话'),
        content: const Text('确定清空本机保存的助手对话历史吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _configService.clearMessages();
    if (!mounted) return;
    setState(() => _messages = []);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgScaffold,
      appBar: AppBar(
        title: const Text('助手'),
        actions: [
          IconButton(
            tooltip: '新建对话',
            onPressed: _messages.isEmpty || _sending
                ? null
                : _clearConversation,
            icon: const Icon(Icons.add_comment_outlined),
          ),
          IconButton(
            tooltip: '模型配置',
            onPressed: _openConfig,
            icon: const Icon(Icons.tune_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (!_config.isComplete) _ConfigBanner(onTap: _openConfig),
                Expanded(
                  child: _messages.isEmpty
                      ? _AssistantEmptyState(configured: _config.isComplete)
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                          itemCount: _messages.length + (_sending ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (_sending && index == _messages.length) {
                              return const _ThinkingRow();
                            }
                            return _AssistantMessageView(
                              message: _messages[index],
                            );
                          },
                        ),
                ),
                _AssistantInputBar(
                  controller: _inputController,
                  focusNode: _inputFocusNode,
                  enabled: !_sending,
                  onSend: _send,
                ),
              ],
            ),
    );
  }
}

class _ConfigBanner extends StatelessWidget {
  final VoidCallback onTap;

  const _ConfigBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.primaryColor.withValues(alpha: 0.08),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded, color: AppTheme.primaryColor),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '请先配置 OpenAI-compatible 模型 API 后开始对话',
                  style: TextStyle(color: AppTheme.textPrimary),
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _AssistantEmptyState extends StatelessWidget {
  final bool configured;

  const _AssistantEmptyState({required this.configured});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                size: 48,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(height: 14),
              Text(
                configured ? '问问你的任务安排' : '先配置模型，再开始对话',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                '助手可以只读检索任务、项目和日历日程，回答今天安排、本周重点、项目进展和时间冲突。',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AssistantMessageView extends StatelessWidget {
  final AssistantMessage message;

  const _AssistantMessageView({required this.message});

  @override
  Widget build(BuildContext context) {
    if (message.isTool) return _ToolMessageCard(message: message);
    final isUser = message.isUser;
    final alignment = isUser ? Alignment.centerRight : Alignment.centerLeft;
    final background = isUser ? AppTheme.primaryColor : AppTheme.bgCard;
    final foreground = isUser ? Colors.white : AppTheme.textPrimary;
    return Align(
      alignment: alignment,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 760),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(14),
          border: isUser ? null : Border.all(color: AppTheme.borderSubtle),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.reasoningContent.trim().isNotEmpty) ...[
              _ReasoningBox(text: message.reasoningContent),
              const SizedBox(height: 10),
            ],
            if (message.content.trim().isNotEmpty)
              isUser
                  ? SelectableText(
                      message.content,
                      style: TextStyle(color: foreground, height: 1.45),
                    )
                  : MarkdownBody(
                      data: message.content,
                      selectable: true,
                      styleSheet: MarkdownStyleSheet.fromTheme(
                        Theme.of(context),
                      ).copyWith(p: TextStyle(color: foreground, height: 1.5)),
                    ),
            if (message.sources.isNotEmpty) ...[
              const SizedBox(height: 10),
              _SourceWrap(sources: message.sources),
            ],
            if (message.toolCalls.isNotEmpty) ...[
              const SizedBox(height: 10),
              _ToolCallWrap(calls: message.toolCalls),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReasoningBox extends StatefulWidget {
  final String text;

  const _ReasoningBox({required this.text});

  @override
  State<_ReasoningBox> createState() => _ReasoningBoxState();
}

class _ReasoningBoxState extends State<_ReasoningBox> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgInput,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.psychology_alt_outlined,
                    size: 16,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '思考过程',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: SelectableText(
                widget.text,
                style: TextStyle(color: AppTheme.textSecondary, height: 1.5),
              ),
            ),
        ],
      ),
    );
  }
}

class _ToolMessageCard extends StatelessWidget {
  final AssistantMessage message;

  const _ToolMessageCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 760),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.bgInput,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderSubtle),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.build_circle_outlined,
                  size: 18,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _toolLabel(message.toolName ?? 'tool'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  '${message.sources.length} 条来源',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
              ],
            ),
            if (message.sources.isNotEmpty) ...[
              const SizedBox(height: 10),
              _SourceWrap(sources: message.sources),
            ],
          ],
        ),
      ),
    );
  }
}

class _ToolCallWrap extends StatelessWidget {
  final List<AssistantToolCall> calls;

  const _ToolCallWrap({required this.calls});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final call in calls)
          Chip(
            avatar: const Icon(Icons.search_rounded, size: 16),
            label: Text(_toolLabel(call.name)),
          ),
      ],
    );
  }
}

class _SourceWrap extends StatelessWidget {
  final List<AssistantSource> sources;

  const _SourceWrap({required this.sources});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final source in sources.take(8))
          Tooltip(
            message: source.snippet,
            child: Chip(
              label: Text(
                '${_sourceType(source.type)} · ${source.title}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
      ],
    );
  }
}

class _ThinkingRow extends StatelessWidget {
  const _ThinkingRow();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(width: 8),
          Text('正在思考并调用工具...', style: TextStyle(color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}

class _AssistantInputBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final VoidCallback onSend;

  const _AssistantInputBar({
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          border: Border(top: BorderSide(color: AppTheme.borderSubtle)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Focus(
                onKeyEvent: (node, event) {
                  if (!enabled || event is! KeyDownEvent) {
                    return KeyEventResult.ignored;
                  }
                  if (event.logicalKey == LogicalKeyboardKey.enter &&
                      !HardwareKeyboard.instance.isShiftPressed) {
                    onSend();
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  enabled: enabled,
                  minLines: 1,
                  maxLines: 5,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) {
                    if (enabled) onSend();
                  },
                  decoration: InputDecoration(
                    hintText: '问问今天安排、项目进展或本周重点',
                    filled: true,
                    fillColor: AppTheme.bgInput,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            IconButton.filled(
              tooltip: '发送',
              onPressed: enabled ? onSend : null,
              icon: const Icon(Icons.send_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _AssistantConfigDialog extends StatefulWidget {
  final AssistantModelConfig config;

  const _AssistantConfigDialog({required this.config});

  @override
  State<_AssistantConfigDialog> createState() => _AssistantConfigDialogState();
}

class _AssistantConfigDialogState extends State<_AssistantConfigDialog> {
  late final _baseUrl = TextEditingController(text: widget.config.baseUrl);
  late final _apiPath = TextEditingController(text: widget.config.apiPath);
  late final _apiKey = TextEditingController(text: widget.config.apiKey);
  late final _model = TextEditingController(text: widget.config.model);
  late final _userInstructions = TextEditingController(
    text: widget.config.userInstructions,
  );
  var _testing = false;
  String? _testResult;

  @override
  void dispose() {
    _baseUrl.dispose();
    _apiPath.dispose();
    _apiKey.dispose();
    _model.dispose();
    _userInstructions.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    setState(() { _testing = true; _testResult = null; });
    try {
      final config = AssistantModelConfig(
        baseUrl: _baseUrl.text.trim(),
        apiPath: _apiPath.text.trim(),
        apiKey: _apiKey.text.trim(),
        model: _model.text.trim(),
      );
      await Dio(BaseOptions(connectTimeout: const Duration(seconds: 10))).post(
        config.endpoint,
        options: Options(headers: {
          'Authorization': 'Bearer ${config.apiKey.trim()}',
          'Content-Type': 'application/json',
        }),
        data: {
          'model': config.model.trim(),
          'messages': [const {'role': 'user', 'content': 'Hi'}],
          'max_tokens': 1,
        },
      );
      if (mounted) setState(() => _testResult = '✅ 连接成功');
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = switch (e.response?.statusCode) {
        401 || 403 => '❌ 认证失败（Token 可能已过期）',
        404 => '❌ API 地址不存在',
        422 => '❌ 请求参数错误（模型 ID 可能不对）',
        _ => '❌ 连接失败：${e.message ?? e.toString()}',
      };
      setState(() => _testResult = msg);
    } catch (e) {
      if (mounted) setState(() => _testResult = '❌ 错误：$e');
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('助手模型配置'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field(
                _baseUrl,
                'API Base URL',
                'https://ark.cn-beijing.volces.com/api/coding/v3',
              ),
              const SizedBox(height: 12),
              _field(_apiPath, 'API 路径', '/chat/completions'),
              const SizedBox(height: 12),
              _field(_model, '模型 ID', 'gpt-4o-mini'),
              const SizedBox(height: 12),
              _field(_apiKey, 'API Key', 'sk-...', obscure: true),
              const SizedBox(height: 12),
              _field(
                _userInstructions,
                'CLAUDE.md / 用户偏好',
                '例如：这周完成类任务按本周一 09:00 到周日 18:00 创建跨天任务',
                minLines: 5,
                maxLines: 10,
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (_testResult != null)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text(_testResult!, style: const TextStyle(fontSize: 13)),
          ),
        TextButton(
          onPressed: _testing ? null : _testConnection,
          child: _testing
              ? const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('测试连接'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(
              context,
              AssistantModelConfig(
                baseUrl: _baseUrl.text.trim(),
                apiPath: _apiPath.text.trim(),
                apiKey: _apiKey.text.trim(),
                model: _model.text.trim(),
                userInstructions: _userInstructions.text.trim(),
              ),
            );
          },
          child: const Text('保存'),
        ),
      ],
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    String hint, {
    bool obscure = false,
    int minLines = 1,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      minLines: obscure ? 1 : minLines,
      maxLines: obscure ? 1 : maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
      ),
    );
  }
}

String _toolLabel(String name) {
  return switch (name) {
    'search_tasks' => '检索任务',
    'search_projects' => '检索项目',
    'search_schedules' => '检索日程',
    'get_current_date' => '获取当前日期',
    _ => name,
  };
}

String _sourceType(String type) {
  return switch (type) {
    'task' => '任务',
    'project' => '项目',
    'schedule' => '日程',
    _ => '来源',
  };
}
