import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../services/local_storage_service.dart';

class ProfileEditPage extends StatefulWidget {
  final String accountText;

  const ProfileEditPage({super.key, this.accountText = ''});

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  final _storage = LocalStorageService();
  final _nameController = TextEditingController();
  final _occupationController = TextEditingController();
  final _cityController = TextEditingController();
  final _targetCityController = TextEditingController();
  final _goalsController = TextEditingController();
  Map<String, dynamic> _originalProfile = {};
  bool _ready = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _storage.init();
    final profile = _storage.getExplicitProfile() ?? {};
    _originalProfile = Map<String, dynamic>.from(profile);
    _nameController.text = _stringValue(profile['name']);
    _occupationController.text = _stringValue(profile['occupation']);
    _cityController.text = _stringValue(profile['city']);
    _targetCityController.text = _stringValue(profile['targetExamCity']);
    _goalsController.text = _listValue(
      profile['primaryGoals'] ?? profile['goals'],
    ).join('\n');
    if (!mounted) return;
    setState(() => _ready = true);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _occupationController.dispose();
    _cityController.dispose();
    _targetCityController.dispose();
    _goalsController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final goals = _goalsController.text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    final nextProfile = <String, dynamic>{
      ..._originalProfile,
      'name': _nameController.text.trim(),
      'occupation': _occupationController.text.trim(),
      'city': _cityController.text.trim(),
      'targetExamCity': _targetCityController.text.trim(),
      'primaryGoals': goals,
      'goals': goals,
    };
    await _storage.saveExplicitProfile(nextProfile);
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('编辑资料'),
        actions: [
          IconButton(
            key: const Key('profile_edit_save_icon'),
            tooltip: '保存',
            onPressed: (!_ready || _saving) ? null : _save,
            icon: const Icon(Icons.check_rounded),
          ),
        ],
      ),
      body: !_ready
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                _InfoCard(accountText: widget.accountText),
                const SizedBox(height: 14),
                _SectionCard(
                  title: '基本资料',
                  children: [
                    _TextInput(
                      key: const Key('profile_edit_name'),
                      controller: _nameController,
                      label: '昵称',
                      icon: Icons.badge_outlined,
                    ),
                    const SizedBox(height: 12),
                    _TextInput(
                      key: const Key('profile_edit_occupation'),
                      controller: _occupationController,
                      label: '职业或身份',
                      icon: Icons.work_outline_rounded,
                    ),
                    const SizedBox(height: 12),
                    _TextInput(
                      key: const Key('profile_edit_city'),
                      controller: _cityController,
                      label: '所在城市',
                      icon: Icons.location_city_outlined,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _SectionCard(
                  title: '目标偏好',
                  children: [
                    _TextInput(
                      key: const Key('profile_edit_target_city'),
                      controller: _targetCityController,
                      label: '目标城市（可选）',
                      icon: Icons.flag_outlined,
                    ),
                    const SizedBox(height: 12),
                    _TextInput(
                      key: const Key('profile_edit_goals'),
                      controller: _goalsController,
                      label: '主要目标（每行一个）',
                      icon: Icons.track_changes_outlined,
                      minLines: 3,
                      maxLines: 5,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  key: const Key('profile_edit_save_button'),
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(_saving ? '保存中' : '保存资料'),
                ),
              ],
            ),
    );
  }

  String _stringValue(Object? value) {
    return value is String ? value : '';
  }

  List<String> _listValue(Object? value) {
    if (value is List) {
      return value.whereType<String>().toList();
    }
    return const [];
  }
}

class _InfoCard extends StatelessWidget {
  final String accountText;

  const _InfoCard({required this.accountText});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadowLight,
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline_rounded, color: AppTheme.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '账号信息不可在这里修改',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  accountText.isEmpty ? '登录邮箱、手机号和账号 ID 属于认证信息。' : accountText,
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadowLight,
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _TextInput extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final int minLines;
  final int maxLines;

  const _TextInput({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.minLines = 1,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      minLines: minLines,
      maxLines: maxLines,
      textInputAction: maxLines == 1
          ? TextInputAction.next
          : TextInputAction.newline,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
