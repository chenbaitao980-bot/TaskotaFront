import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/utils/platform_utils.dart';

class BatteryOptimizationGuide {
  static const _dismissedKey = 'battery_optimization_guide_dismissed';

  static const _brandSettings = <String, _BrandGuide>{
    'xiaomi': _BrandGuide(
      brand: '小米/Redmi',
      steps: [
        '设置 → 应用设置 → 应用管理',
        '找到 Taskora → 省电策略 → 选择"无限制"',
        '返回 → 自启动管理 → 开启 Taskora 自启动',
      ],
    ),
    'redmi': _BrandGuide(
      brand: '小米/Redmi',
      steps: [
        '设置 → 应用设置 → 应用管理',
        '找到 Taskora → 省电策略 → 选择"无限制"',
        '返回 → 自启动管理 → 开启 Taskora 自启动',
      ],
    ),
    'huawei': _BrandGuide(
      brand: '华为/荣耀',
      steps: [
        '设置 → 电池 → 更多电池设置',
        '关闭"休眠时始终保持网络连接"以外的省电项',
        '设置 → 应用和服务 → 应用启动管理 → 关闭 Taskora 的自动管理',
      ],
    ),
    'honor': _BrandGuide(
      brand: '华为/荣耀',
      steps: [
        '设置 → 电池 → 更多电池设置',
        '关闭"休眠时始终保持网络连接"以外的省电项',
        '设置 → 应用和服务 → 应用启动管理 → 关闭 Taskora 的自动管理',
      ],
    ),
    'oppo': _BrandGuide(
      brand: 'OPPO/realme',
      steps: [
        '设置 → 电池 → 更多设置',
        '关闭"睡眠待机优化"',
        '设置 → 应用管理 → Taskora → 耗电保护 → 选择"允许后台运行"',
      ],
    ),
    'realme': _BrandGuide(
      brand: 'OPPO/realme',
      steps: [
        '设置 → 电池 → 更多设置',
        '关闭"睡眠待机优化"',
        '设置 → 应用管理 → Taskora → 耗电保护 → 选择"允许后台运行"',
      ],
    ),
    'vivo': _BrandGuide(
      brand: 'vivo/iQOO',
      steps: [
        '设置 → 电池 → 后台高耗电',
        '开启 Taskora 的后台高耗电权限',
        '设置 → 应用与权限 → 自启动管理 → 开启 Taskora',
      ],
    ),
    'iqoo': _BrandGuide(
      brand: 'vivo/iQOO',
      steps: [
        '设置 → 电池 → 后台高耗电',
        '开启 Taskora 的后台高耗电权限',
        '设置 → 应用与权限 → 自启动管理 → 开启 Taskora',
      ],
    ),
    'samsung': _BrandGuide(
      brand: '三星',
      steps: [
        '设置 → 电池和设备维护 → 电池',
        '后台使用限制 → 从不自动休眠应用 → 添加 Taskora',
      ],
    ),
  };

  static _BrandGuide _detectBrand(String manufacturer) {
    final lower = manufacturer.toLowerCase();
    for (final entry in _brandSettings.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }
    return const _BrandGuide(
      brand: 'Android',
      steps: [
        '设置 → 电池 → 电池优化',
        '找到 Taskora → 选择"不优化"或"无限制"',
      ],
    );
  }

  static Future<bool> shouldShow() async {
    if (!isAndroid) return false;
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_dismissedKey) ?? false);
  }

  static Future<void> dismiss() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_dismissedKey, true);
  }

  static const _channel = MethodChannel('com.taskora/battery');

  static Future<String> _getManufacturer() async {
    try {
      final result = await _channel.invokeMethod<String>('getManufacturer');
      return result ?? '';
    } catch (_) {
      return '';
    }
  }

  static Future<void> _requestIgnoreBatteryOptimization() async {
    try {
      await _channel.invokeMethod('requestIgnoreBatteryOptimizations');
    } catch (_) {}
  }

  static Future<void> showGuideIfNeeded(BuildContext context) async {
    if (!await shouldShow()) return;
    if (!context.mounted) return;

    final manufacturer = await _getManufacturer();
    final guide = _detectBrand(manufacturer);

    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _BatteryGuideDialog(guide: guide),
    );
  }
}

class _BrandGuide {
  final String brand;
  final List<String> steps;

  const _BrandGuide({required this.brand, required this.steps});
}

class _BatteryGuideDialog extends StatelessWidget {
  final _BrandGuide guide;

  const _BatteryGuideDialog({required this.guide});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.battery_alert, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('开启后台运行权限', style: TextStyle(fontSize: 18)),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '为确保任务提醒准时送达，请关闭电池优化并允许后台运行。',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${guide.brand} 设置步骤：',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...guide.steps.asMap().entries.map((entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${entry.key + 1}. ',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            entry.value,
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  )),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () async {
            await BatteryOptimizationGuide.dismiss();
            if (context.mounted) Navigator.of(context).pop();
          },
          child: const Text('不再提示'),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('稍后设置'),
        ),
        FilledButton(
          onPressed: () async {
            await BatteryOptimizationGuide._requestIgnoreBatteryOptimization();
            await BatteryOptimizationGuide.dismiss();
            if (context.mounted) Navigator.of(context).pop();
          },
          child: const Text('去设置'),
        ),
      ],
    );
  }
}
