// 覆盖测试: DesktopFloatingTaskTab 便签卡片 widget（直接层）
// 变更点: ea86621 方案A 美化（去整圈彩色描边 + radius12 + 透明 bgCard + boxShadow 分层）
// Layer: 直接
// TestedSource: DesktopFloatingTaskTab@425e7564f1881ab73d67f37b83b673f31427bd37
//
// 业务不变量:
// 1. 卡片无 Border.all（黑线根因之一 = 0.48 alpha 优先级色描边，已移除）
// 2. 点击卡片/打开按钮触发 onTap；关闭按钮触发 onClose
// 3. extraTaskCount>0 显示 +N 徽标；==0 不显示
// 4. 显示标题 + 优先级标签 + 时间

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_assistant/core/desktop/desktop_floating_tab_controller.dart';
import 'package:smart_assistant/core/theme/app_theme.dart';
import 'package:smart_assistant/presentation/widgets/desktop_floating_task_tab.dart';

DesktopFloatingTaskSummary _summary({
  String taskId = 't1',
  String title = '写周报',
  int priority = 3,
  DateTime? anchor,
  DateTime? due,
  int extra = 0,
}) {
  return DesktopFloatingTaskSummary(
    taskId: taskId,
    title: title,
    priority: priority,
    anchorDate: anchor ?? DateTime(2026, 8, 4, 9, 30),
    dueDate: due,
    extraTaskCount: extra,
  );
}

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('渲染标题/优先级标签/时间，无整圈彩色描边', (tester) async {
    final summary = _summary(due: DateTime(2026, 8, 5, 18, 0));
    await tester.pumpWidget(_wrap(
      DesktopFloatingTaskTab(
        task: summary,
        onTap: () {},
        onClose: () async {},
      ),
    ));
    expect(find.text('写周报'), findsOneWidget);
    expect(find.text('当前进行中'), findsOneWidget);
    expect(find.text('P1 重要 · 08-05 18:00'), findsOneWidget);

    // 无整圈彩色描边：卡片内层 Material 用 bgCard + antiAlias，外层无 Border.all
    final materials = tester.widgetList<Material>(find.byType(Material)).toList();
    expect(materials.any((m) => m.color == AppTheme.bgCard), isTrue,
        reason: '卡片应使用 bgCard 100% 不透明卡');
    // 整个 widget 树中任何 BoxDecoration 都不应带 border（黑线根因 = 整圈彩色描边）
    final borders = tester
        .widgetList<Container>(find.byType(Container))
        .where((c) => c.decoration is BoxDecoration)
        .map((c) => (c.decoration as BoxDecoration).border)
        .where((b) => b != null);
    expect(borders, isEmpty, reason: '便签卡片任何层不应有整圈描边（黑线根因）');
  });

  test('AppTheme.cardShadow 存在且非空（阴影从 Material elevation 迁到 boxShadow）', () {
    expect(AppTheme.cardShadow, isNotEmpty, reason: '阴影分层依赖 cardShadow 配置');
    expect(AppTheme.bgCard, isNotNull);
  });

  testWidgets('extraTaskCount>0 显示 +N 徽标，=0 不显示', (tester) async {
    await tester.pumpWidget(_wrap(
      DesktopFloatingTaskTab(
        task: _summary(extra: 3),
        onTap: () {},
        onClose: () async {},
      ),
    ));
    expect(find.text('+3'), findsOneWidget);

    await tester.pumpWidget(_wrap(
      DesktopFloatingTaskTab(
        task: _summary(extra: 0),
        onTap: () {},
        onClose: () async {},
      ),
    ));
    expect(find.textContaining('+'), findsNothing,
        reason: 'extraTaskCount==0 不应显示 +0 徽标');
  });

  testWidgets('点击打开按钮触发 onTap；点击关闭按钮触发 onClose', (tester) async {
    var tapped = false;
    var closed = false;
    await tester.pumpWidget(_wrap(
      DesktopFloatingTaskTab(
        task: _summary(),
        onTap: () => tapped = true,
        onClose: () async => closed = true,
      ),
    ));
    await tester.tap(find.byIcon(Icons.open_in_full_rounded));
    await tester.pump(const Duration(milliseconds: 350));
    expect(tapped, isTrue, reason: '点击打开图标应触发 onTap（唤起主窗定位）');

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pump(const Duration(milliseconds: 350));
    expect(closed, isTrue, reason: '点击关闭图标应触发 onClose（置 dismissed）');
  });

  testWidgets('点击卡片主体（InkWell）触发 onTap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(_wrap(
      DesktopFloatingTaskTab(
        task: _summary(),
        onTap: () => tapped = true,
        onClose: () async {},
      ),
    ));
    await tester.tap(find.text('写周报'));
    await tester.pump(const Duration(milliseconds: 350));
    expect(tapped, isTrue);
  });
}
