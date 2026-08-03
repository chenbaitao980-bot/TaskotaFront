import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_assistant/presentation/pages/home/lazy_log_creation_dialog.dart';
import 'package:smart_assistant/presentation/widgets/task_tree_picker_sheet.dart';

List<LazyLogParentOption> _tree() => const [
  LazyLogParentOption(id: 'A', title: '根任务A'),
  LazyLogParentOption(id: 'A1', title: '子任务A1', parentId: 'A'),
  LazyLogParentOption(id: 'A1a', title: '孙任务A1a', parentId: 'A1'),
  LazyLogParentOption(id: 'B', title: '根任务B'),
  LazyLogParentOption(id: 'B1', title: '子任务B1', parentId: 'B'),
];

Widget _app(List<LazyLogParentOption> parents, {String? selectedId}) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        height: 500,
        child: TaskTreePickerSheet(parents: parents, selectedId: selectedId),
      ),
    ),
  );
}

/// 打开 bottom sheet 弹层并捕获 pop 结果 Future。
Future<Future<LazyLogParentOption?>?> openSheet(
  WidgetTester tester, {
  String? selectedId,
}) async {
  Future<LazyLogParentOption?>? result;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () {
                result = showModalBottomSheet<LazyLogParentOption>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => SizedBox(
                    height: 400,
                    child: TaskTreePickerSheet(
                      parents: _tree(),
                      selectedId: selectedId,
                    ),
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return result;
}

void main() {
  testWidgets('D1: 默认收缩 —— 无选中项打开，根可见、子任务隐藏', (tester) async {
    await tester.pumpWidget(_app(_tree()));
    expect(find.text('根任务A'), findsOneWidget);
    expect(find.text('根任务B'), findsOneWidget);
    expect(find.text('子任务A1'), findsNothing);
    expect(find.text('子任务B1'), findsNothing);
  });

  testWidgets('D6: 有选中项打开自动展开祖先路径，其余分支仍收缩', (tester) async {
    await tester.pumpWidget(_app(_tree(), selectedId: 'A1'));
    // A → A1 祖先链展开：子任务A1 可见且带勾选
    expect(find.text('子任务A1'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    // B 分支未展开 → 子任务B1 隐藏
    expect(find.text('根任务B'), findsOneWidget);
    expect(find.text('子任务B1'), findsNothing);
  });

  testWidgets('D4: 一键展开全部 / 一键收起全部', (tester) async {
    await tester.pumpWidget(_app(_tree()));
    expect(find.text('子任务A1'), findsNothing);

    // 全折叠态 → 图标为 unfold_more（展开全部）
    await tester.tap(find.byIcon(Icons.unfold_more_rounded));
    await tester.pumpAndSettle();
    expect(find.text('子任务A1'), findsOneWidget);
    expect(find.text('孙任务A1a'), findsOneWidget);
    expect(find.text('子任务B1'), findsOneWidget);

    // 展开态 → 图标变为 unfold_less（收起全部）
    await tester.tap(find.byIcon(Icons.unfold_less_rounded));
    await tester.pumpAndSettle();
    expect(find.text('子任务A1'), findsNothing);
    expect(find.text('子任务B1'), findsNothing);
  });

  testWidgets('D3: 再点已选节点取消勾选，窗口保持打开，完成→清空哨兵', (tester) async {
    final result = await openSheet(tester, selectedId: 'A1');
    expect(find.text('子任务A1'), findsOneWidget);

    await tester.tap(find.text('子任务A1'));
    await tester.pumpAndSettle();
    // 取消勾选：check 消失、弹层仍在（未关闭）
    expect(find.byIcon(Icons.check_circle_rounded), findsNothing);
    expect(find.byType(TaskTreePickerSheet), findsOneWidget);

    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();
    final picked = await result!;
    expect(picked, same(TaskTreePickerSheet.clearSelection));
  });

  testWidgets('D2: 点未选中节点切换勾选，完成→返回该节点', (tester) async {
    final result = await openSheet(tester);
    // 先一键展开让 B1 可见
    await tester.tap(find.byIcon(Icons.unfold_more_rounded));
    await tester.pumpAndSettle();

    await tester.tap(find.text('子任务A1'));
    await tester.pumpAndSettle();
    // 勾选 A1、弹层仍在
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    expect(find.byType(TaskTreePickerSheet), findsOneWidget);

    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();
    final picked = await result!;
    expect(picked, isNotNull);
    expect(picked!.id, 'A1');
    expect(identical(picked, TaskTreePickerSheet.clearSelection), isFalse);
  });

  testWidgets('D5: 点 header 关闭X → pop null（不保存不误清）', (tester) async {
    final result = await openSheet(tester, selectedId: 'A1');
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    final picked = await result!;
    expect(picked, isNull);
  });

  testWidgets('D7: 无勾选直接点完成 → clearSelection（审核页幂等清空）', (tester) async {
    final result = await openSheet(tester);
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();
    final picked = await result!;
    expect(picked, same(TaskTreePickerSheet.clearSelection));
  });

  testWidgets('搜索过滤 + 切换勾选 + 完成回填', (tester) async {
    final result = await openSheet(tester);
    await tester.enterText(find.byType(TextField), 'A1a');
    await tester.pumpAndSettle();
    expect(find.text('孙任务A1a'), findsOneWidget);
    expect(find.text('根任务A'), findsNothing);

    await tester.tap(find.text('孙任务A1a'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    expect(find.byType(TaskTreePickerSheet), findsOneWidget);

    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();
    final picked = await result!;
    expect(picked, isNotNull);
    expect(picked!.id, 'A1a');
  });

  testWidgets('shows empty state when project has no tasks', (tester) async {
    await tester.pumpWidget(_app(const []));
    expect(find.text('该项目暂无任务'), findsOneWidget);
  });

  testWidgets('marks selected node with check icon', (tester) async {
    await tester.pumpWidget(_app(_tree(), selectedId: 'A1'));
    expect(find.text('子任务A1'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
  });

  testWidgets('C4: 已选节点点 chevron 仅折叠，不切换勾选、不关闭', (tester) async {
    // selectedId='A1' → A、A1 祖先链展开 → 孙节点可见
    await tester.pumpWidget(_app(_tree(), selectedId: 'A1'));
    expect(find.text('孙任务A1a'), findsOneWidget);

    final a1Row = find
        .ancestor(
          of: find.text('子任务A1'),
          matching: find.byType(InkWell),
        )
        .first;
    await tester.tap(
      find.descendant(of: a1Row, matching: find.byIcon(Icons.expand_more_rounded)),
    );
    await tester.pumpAndSettle();
    // 折叠 → 孙节点隐藏；勾选仍保留（未切换）；弹层仍在
    expect(find.text('孙任务A1a'), findsNothing);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    expect(find.byType(TaskTreePickerSheet), findsOneWidget);
  });
}
