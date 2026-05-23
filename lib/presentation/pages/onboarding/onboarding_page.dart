import 'package:flutter/material.dart';
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
  final List<String> _goals = ['', '', ''];
  final List<String> _levels = ['', '', ''];

  static const _levelOptions = ['零基础', '初级入门', '有基础', '中级', '高级'];

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
      'goals': _goals.where((g) => g.isNotEmpty).toList(),
      'levels': _levels.where((l) => l.isNotEmpty).toList(),
    });
    await storage.setOnboardingCompleted();
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgScaffold,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _step > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _step--),
              )
            : null,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProgress(),
              const SizedBox(height: 32),
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
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
        ),
        const Spacer(),
        ...List.generate(3, (i) {
          return Container(
            width: 24,
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
    switch (_step) {
      case 0:
        return _buildBasicInfo();
      case 1:
        return _buildGoals();
      case 2:
        return _buildLevels();
      default:
        return const SizedBox();
    }
  }

  Widget _buildBasicInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('先认识一下你 👋',
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('这些信息帮助 AI 更好地了解你的背景',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
        const SizedBox(height: 32),
        TextField(
          controller: _nameController,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: const InputDecoration(
            labelText: '你的名字',
            labelStyle: TextStyle(color: AppTheme.textSecondary),
            filled: true,
            fillColor: AppTheme.bgCard,
            border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.all(Radius.circular(12))),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _occupationController,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: const InputDecoration(
            labelText: '职业（选填）',
            labelStyle: TextStyle(color: AppTheme.textSecondary),
            filled: true,
            fillColor: AppTheme.bgCard,
            border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.all(Radius.circular(12))),
          ),
        ),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _nextStep,
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('下一步', style: TextStyle(fontSize: 16)),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildGoals() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('你想达成什么目标？',
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('最多 3 个，比如"考过N1""存5万""减10斤"',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
        const SizedBox(height: 32),
        ...List.generate(3, (i) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TextField(
              onChanged: (v) => _goals[i] = v,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                labelText: '目标 ${i + 1}（${i == 0 ? '必填' : '选填'}）',
                labelStyle: const TextStyle(color: AppTheme.textSecondary),
                filled: true,
                fillColor: AppTheme.bgCard,
                border: const OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.all(Radius.circular(12))),
              ),
            ),
          );
        }),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _goals.first.isNotEmpty ? _nextStep : null,
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('下一步', style: TextStyle(fontSize: 16)),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildLevels() {
    final nonEmptyGoals = _goals.where((g) => g.isNotEmpty).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('你目前在这些领域是什么水平？',
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('这帮助 AI 为你定制个性化的任务拆解',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
        const SizedBox(height: 24),
        ...nonEmptyGoals.asMap().entries.map((entry) {
          final idx = entry.key;
          final goal = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(goal,
                    style: const TextStyle(color: AppTheme.primaryColor, fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _levelOptions.map((level) {
                    final selected = _levels[idx] == level;
                    return ChoiceChip(
                      label: Text(level),
                      selected: selected,
                      selectedColor: AppTheme.primaryColor.withValues(alpha: 0.3),
                      backgroundColor: AppTheme.bgCard,
                      labelStyle: TextStyle(
                        color: selected ? AppTheme.primaryColor : AppTheme.textSecondary,
                      ),
                      onSelected: (_) => setState(() => _levels[idx] = level),
                    );
                  }).toList(),
                ),
              ],
            ),
          );
        }),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => _complete(),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('开始使用', style: TextStyle(fontSize: 16)),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _occupationController.dispose();
    super.dispose();
  }
}
