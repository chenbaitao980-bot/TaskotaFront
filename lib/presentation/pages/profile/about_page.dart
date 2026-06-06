import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  static const _version = '1.0.0+3';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('关于')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppTheme.bgCard,
              borderRadius: BorderRadius.circular(16),
              boxShadow: AppTheme.cardShadowLight,
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.white,
                    size: 34,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Taskora',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '版本 $_version',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const _AboutSection(
            title: '核心能力',
            items: [
              '把目标拆成可执行的任务、子任务和检查项。',
              '支持日历视图、任务排期、提醒和重复提醒。',
              '支持附件、Obsidian 链接、项目分组和多主题切换。',
            ],
          ),
          SizedBox(height: 14),
          const _AboutSection(
            title: '数据与同步',
            items: [
              '未登录时，任务和偏好设置主要保存在本机。',
              '登录后，任务、项目、检查项和附件元数据会通过 Supabase 同步。',
              '本地数据以设备应用数据目录为准，卸载或清理应用数据会影响本地记录。',
            ],
          ),
          SizedBox(height: 14),
          const _AboutSection(
            title: '隐私与权限',
            items: [
              '通知权限用于任务和日程提醒。',
              '文件访问只在用户主动选择或打开附件时使用。',
              'AI 拆解会处理用户主动提交的任务标题、描述和相关附件文本。',
            ],
          ),
        ],
      ),
    );
  }
}

class _AboutSection extends StatelessWidget {
  final String title;
  final List<String> items;

  const _AboutSection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadowLight,
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
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
          const SizedBox(height: 10),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 7),
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                        height: 1.5,
                      ),
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
