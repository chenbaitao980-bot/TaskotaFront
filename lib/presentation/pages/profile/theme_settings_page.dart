import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_controller.dart';

class ThemeSettingsPage extends StatefulWidget {
  const ThemeSettingsPage({super.key});

  @override
  State<ThemeSettingsPage> createState() => _ThemeSettingsPageState();
}

class _ThemeSettingsPageState extends State<ThemeSettingsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('主题')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          for (final palette in AppPalette.all) ...[
            _ThemeCard(
              palette: palette,
              selected: themeController.current == palette.id,
              onTap: () async {
                await themeController.setTheme(palette.id);
                if (mounted) setState(() {});
              },
            ),
            const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}

class _ThemeCard extends StatelessWidget {
  final AppPalette palette;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeCard({
    required this.palette,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? palette.primaryColor : AppTheme.borderSubtle,
            width: selected ? 2 : 0.5,
          ),
          boxShadow: AppTheme.cardShadowLight,
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // 预览样本
            _Preview(palette: palette),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    palette.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    palette.isDark ? '深色模式' : '亮色模式',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
            Icon(
              selected ? Icons.check_circle_rounded : Icons.circle_outlined,
              color: selected ? palette.primaryColor : AppTheme.textHint,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}

/// 用该主题自身颜色绘制的迷你预览。
class _Preview extends StatelessWidget {
  final AppPalette palette;
  const _Preview({required this.palette});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: palette.bgScaffold,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.borderSubtle, width: 0.5),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 28,
            height: 6,
            decoration: BoxDecoration(
              color: palette.primaryColor,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          Container(
            width: double.infinity,
            height: 14,
            decoration: BoxDecoration(
              color: palette.bgCard,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Row(
            children: [
              Container(width: 14, height: 6, color: palette.textSecondary),
              const SizedBox(width: 4),
              Container(width: 10, height: 6, color: palette.accent),
            ],
          ),
        ],
      ),
    );
  }
}
