import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class HelpFeedbackPage extends StatelessWidget {
  const HelpFeedbackPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('帮助与反馈')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: const [
          _HelpSection(
            title: '常用功能',
            items: [
              _HelpItem(
                icon: Icons.task_alt_rounded,
                title: '任务管理',
                body: '在任务页创建目标、项目和子任务，可用清单、附件和 Obsidian 链接补充任务资料。',
              ),
              _HelpItem(
                icon: Icons.auto_awesome_rounded,
                title: 'AI 拆解',
                body: '在首页输入目标或任务描述，AI 会生成 WBS 子任务，并按工作时段尝试安排执行时间。',
              ),
              _HelpItem(
                icon: Icons.calendar_month_outlined,
                title: '日历提醒',
                body: '日历页展示日程和已排期任务；创建日程时可设置提前提醒和重复提醒。',
              ),
              _HelpItem(
                icon: Icons.palette_outlined,
                title: '主题切换',
                body: '在我的页或设置页进入主题，选择暖珊瑚、极光蓝或曜石黑。',
              ),
            ],
          ),
          SizedBox(height: 14),
          _HelpSection(
            title: '常见问题',
            items: [
              _HelpItem(
                icon: Icons.notifications_none_rounded,
                title: '为什么提醒没有响？',
                body: '请确认系统通知权限已开启；Android 还需要允许精确闹钟权限，桌面端需要应用保持运行。',
              ),
              _HelpItem(
                icon: Icons.sync_problem_rounded,
                title: '为什么多端数据不一致？',
                body: '云同步只在登录后启用。重新打开应用或切换登录状态后会进行一次全量对账。',
              ),
              _HelpItem(
                icon: Icons.attach_file_rounded,
                title: '附件打不开怎么办？',
                body: '附件依赖本机文件路径或已同步的附件记录；如果源文件被移动或删除，需要重新添加。',
              ),
            ],
          ),
          SizedBox(height: 14),
          _HelpSection(
            title: '反馈方式',
            items: [
              _HelpItem(
                icon: Icons.feedback_outlined,
                title: '问题反馈',
                body: '反馈时请附上操作步骤、发生页面、系统平台和截图，便于定位问题。',
              ),
              _HelpItem(
                icon: Icons.lightbulb_outline_rounded,
                title: '功能建议',
                body: '可以描述你的使用场景、期望结果和当前绕路方式，后续会按影响面评估优先级。',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HelpSection extends StatelessWidget {
  final String title;
  final List<_HelpItem> items;

  const _HelpSection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadowLight,
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
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
          ...items,
        ],
      ),
    );
  }
}

class _HelpItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _HelpItem({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.primaryColor, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                    height: 1.5,
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
