import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/local_storage_service.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  int _step = 0;
  final _nameController = TextEditingController();
  final _occupationController = TextEditingController();
  late final List<TextEditingController> _goalControllers;
  final List<String> _levels = ['', '', ''];

  static const _levelOptions = ['零基础', '初级入门', '有基础', '中级', '高级'];

  @override
  void initState() {
    super.initState();
    _goalControllers = List.generate(3, (_) => TextEditingController());
    for (final controller in _goalControllers) {
      controller.addListener(_refreshGoalValidation);
    }
  }

  List<String> get _goals => _goalControllers
      .map((controller) => controller.text.trim())
      .where((goal) => goal.isNotEmpty)
      .toList();

  bool get _canContinueGoals => _goals.isNotEmpty;

  void _refreshGoalValidation() {
    if (mounted) setState(() {});
  }

  void _nextStep() {
    if (_step < 2) {
      setState(() => _step++);
    } else {
      _complete();
    }
  }

  Future<void> _complete() async {
    final storage = LocalStorageService();
    await storage.init();
    await storage.saveExplicitProfile({
      'name': _nameController.text.trim(),
      'occupation': _occupationController.text.trim(),
      'goals': _goals,
      'levels': _levels.where((level) => level.isNotEmpty).toList(),
    });
    await storage.setOnboardingCompleted();
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _skipOnboarding() async {
    final storage = LocalStorageService();
    await storage.init();
    await storage.setOnboardingCompleted();
    if (mounted) Navigator.of(context).pop(false);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _occupationController.dispose();
    for (final controller in _goalControllers) {
      controller
        ..removeListener(_refreshGoalValidation)
        ..dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgScaffold,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: _step > 0
            ? IconButton(
                tooltip: '上一步',
                icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                onPressed: () => setState(() => _step--),
              )
            : null,
        actions: [
          IconButton(
            tooltip: '返回首页',
            icon: const Icon(Icons.close_rounded, size: 20),
            onPressed: _skipOnboarding,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProgress(),
              const SizedBox(height: 36),
              Expanded(child: _buildStep()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgress() {
    return Row(
      children: [
        Text(
          '第 ${_step + 1} 步 / 共 3 步',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
        ),
        const Spacer(),
        ...List.generate(3, (i) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: i == _step ? 32 : 24,
            height: 4,
            margin: const EdgeInsets.only(left: 4),
            decoration: BoxDecoration(
              color: i <= _step ? AppTheme.primaryColor : AppTheme.borderSubtle,
              borderRadius: BorderRadius.circular(2),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildStep() {
    return switch (_step) {
      0 => _buildBasicInfo(),
      1 => _buildGoals(),
      2 => _buildLevels(),
      _ => const SizedBox(),
    };
  }

  Widget _buildBasicInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '先认识一下你',
          style: GoogleFonts.instrumentSerifTextTheme().displaySmall?.copyWith(
            color: AppTheme.textPrimary,
            fontSize: 28,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '这些信息都是可选项，之后也可以再补充。',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 15),
        ),
        const SizedBox(height: 32),
        TextField(
          controller: _nameController,
          style: TextStyle(color: AppTheme.textPrimary, fontSize: 15),
          decoration: const InputDecoration(labelText: '你的名字（可选）'),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _occupationController,
          style: TextStyle(color: AppTheme.textPrimary, fontSize: 15),
          decoration: const InputDecoration(labelText: '职业（可选）'),
        ),
        const Spacer(),
        _primaryButton('下一步', _nextStep),
        const SizedBox(height: 8),
        _secondaryButton('暂不填写，进入首页', _skipOnboarding),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildGoals() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '你想达成什么目标？',
          style: GoogleFonts.instrumentSerifTextTheme().displaySmall?.copyWith(
            color: AppTheme.textPrimary,
            fontSize: 28,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '最多 3 个，比如“考过 N1”“学吉他”“减 10 斤”。',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 15),
        ),
        const SizedBox(height: 28),
        ...List.generate(3, (i) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TextField(
              controller: _goalControllers[i],
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 15),
              decoration: InputDecoration(
                labelText: '目标 ${i + 1}（${i == 0 ? '至少填一个' : '可选'}）',
              ),
            ),
          );
        }),
        const Spacer(),
        _primaryButton('下一步', _canContinueGoals ? _nextStep : null),
        const SizedBox(height: 8),
        _secondaryButton('暂不填写，进入首页', _skipOnboarding),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildLevels() {
    final goals = _goals;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '现在是什么水平？',
          style: GoogleFonts.instrumentSerifTextTheme().displaySmall?.copyWith(
            color: AppTheme.textPrimary,
            fontSize: 28,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '可以跳过，AI 会在拆解任务时继续追问。',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 15),
        ),
        const SizedBox(height: 28),
        Expanded(
          child: ListView(
            children: goals.asMap().entries.map((entry) {
              final idx = entry.key;
              final goal = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        goal,
                        style: TextStyle(
                          color: AppTheme.primaryColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _levelOptions.map((level) {
                        final selected = _levels[idx] == level;
                        return ChoiceChip(
                          label: Text(
                            level,
                            style: TextStyle(
                              fontSize: 13,
                              color: selected
                                  ? AppTheme.primaryColor
                                  : AppTheme.textSecondary,
                            ),
                          ),
                          selected: selected,
                          selectedColor: AppTheme.primaryColor.withValues(
                            alpha: 0.12,
                          ),
                          backgroundColor: AppTheme.bgInput,
                          side: BorderSide(
                            color: selected
                                ? AppTheme.primaryColor
                                : AppTheme.borderSubtle,
                            width: selected ? 1.5 : 0.5,
                          ),
                          onSelected: (_) =>
                              setState(() => _levels[idx] = level),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        _primaryButton('开始使用', _complete),
        const SizedBox(height: 8),
        _secondaryButton('跳过水平，进入首页', _skipOnboarding),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _primaryButton(String label, VoidCallback? onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryColor,
          disabledBackgroundColor: AppTheme.primaryColor.withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(label, style: const TextStyle(fontSize: 16)),
      ),
    );
  }

  Widget _secondaryButton(String label, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: TextButton(onPressed: onPressed, child: Text(label)),
    );
  }
}
