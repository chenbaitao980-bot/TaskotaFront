// TestedSource: _ParentTaskButton + _openPicker + _ProjectDropdown.onChanged + TaskTreePickerSheet@bf3e1cb072553db828e25b7fd3b67fdc2e61b50d
// Layer: DIRECT + UPSTREAM（审核页消费契约）
//
// 审核页父任务选择门控 + 哨兵消费契约：
// 1) 未选项目 → 父任务按钮禁用并提示"先选项目"
// 2) 已选项目 → 可打开树选择器
// 3) 打开树选择器点节点 + 完成 → 写入 parentTaskId
// 4) 再点已选节点取消 + 完成 → clearSelection 哨兵 → 清除父任务
// 5) 切换项目 → 失效父任务一并清除
//
// 说明：审核页基于 drift watch() 的 StreamBuilder，pumpAndSettle 会与持续流冲突，
// 统一用固定时长 pump；测试末尾卸载 widget 树以取消订阅、避免 Timer pending。

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_assistant/data/database/app_database.dart';
import 'package:smart_assistant/data/repositories/lazy_log_draft_repository.dart';
import 'package:smart_assistant/models/assistant/lazy_log_review_models.dart';
import 'package:smart_assistant/presentation/pages/home/lazy_log_creation_dialog.dart';
import 'package:smart_assistant/presentation/pages/home/lazy_log_draft_review_sheet.dart';
import 'package:smart_assistant/presentation/widgets/task_tree_picker_sheet.dart';

const _projects = [
  LazyLogProjectOption(id: 'p1', name: '项目A'),
  LazyLogProjectOption(id: 'p2', name: '项目B'),
];

const _parents = [
  LazyLogParentOption(id: 'A', title: '根任务A', projectId: 'p1'),
  LazyLogParentOption(id: 'A1', title: '子任务A1', parentId: 'A', projectId: 'p1'),
  LazyLogParentOption(id: 'B', title: '根任务B', projectId: 'p2'),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;
  late LazyLogDraftRepository repository;

  Future<LazyLogDraft> seedDraft({String? projectId}) async {
    final running = await repository.createRunning(
      sourceInput: '今天整理懒人日志',
      batchId: 'batch-gate',
    );
    await repository.replaceRunningWithDrafts(
      runningId: running.id,
      drafts: [
        LazyLogDraftWrite(
          batchId: 'batch-gate',
          sourceInput: '今天整理懒人日志',
          summary: '整理懒人日志',
          title: '完善懒人日志审核',
          description: '',
          priority: 'P2',
          projectId: projectId,
          checklist: const [],
          start: DateTime(2026, 7, 15, 9),
          end: DateTime(2026, 7, 15, 10),
          sortOrder: 0,
        ),
      ],
    );
    return (await repository.getPendingReview()).single;
  }

  Future<void> pumpReviewSheet(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LazyLogDraftReviewSheet(
            repository: repository,
            projects: _projects,
            parents: _parents,
            onApprove: (_) async {},
            onRetry: (_) async {},
          ),
        ),
      ),
    );
    await tester.pump(); // StreamBuilder 首帧
    await tester.pump(const Duration(milliseconds: 300));
  }

  // 卸载审核页 widget 树，dispose StreamBuilder 取消 drift 订阅，避免 Timer pending。
  Future<void> teardownTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
  }

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = LazyLogDraftRepository(database);
  });

  tearDown(() => database.close());

  testWidgets('未选项目 → 父任务按钮禁用并提示"先选项目"', (tester) async {
    await seedDraft(); // projectId: null
    await pumpReviewSheet(tester);

    expect(find.text('先选项目'), findsOneWidget);
    final button = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, '先选项目'),
    );
    expect(button.onPressed, isNull);
    await teardownTree(tester);
  });

  testWidgets('已选项目且未选父任务 → 按钮显示"选择父任务"且可点', (tester) async {
    await seedDraft(projectId: 'p1');
    await pumpReviewSheet(tester);

    expect(find.text('选择父任务'), findsOneWidget);
    final button = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, '选择父任务'),
    );
    expect(button.onPressed, isNotNull);
    await teardownTree(tester);
  });

  testWidgets('已选项目且有已选父任务 → 按钮显示父任务标题', (tester) async {
    final draft = await seedDraft(projectId: 'p1');
    await repository.updateDraft(draft.id, parentTaskId: 'A1');
    await pumpReviewSheet(tester);

    expect(find.text('子任务A1'), findsOneWidget);
    final button = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, '子任务A1'),
    );
    expect(button.onPressed, isNotNull);
    await teardownTree(tester);
  });

  testWidgets('打开树选择器选中节点 + 完成 → 写入 parentTaskId', (tester) async {
    await seedDraft(projectId: 'p1');
    await pumpReviewSheet(tester);

    await tester.tap(find.widgetWithText(OutlinedButton, '选择父任务'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600)); // bottom sheet 动画
    expect(find.byType(TaskTreePickerSheet), findsOneWidget);

    // 默认收缩 → 一键展开后点叶子节点
    await tester.tap(find.byIcon(Icons.unfold_more_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('子任务A1'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('完成'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400)); // bottom sheet 关闭

    final updated = (await repository.getPendingReview()).single;
    expect(updated.parentTaskId, 'A1');
    await teardownTree(tester);
  });

  testWidgets('打开树选择器再点已选节点取消 + 完成 → clearSelection 哨兵清除父任务', (tester) async {
    final draft = await seedDraft(projectId: 'p1');
    await repository.updateDraft(draft.id, parentTaskId: 'A1');
    await pumpReviewSheet(tester);

    await tester.tap(find.widgetWithText(OutlinedButton, '子任务A1'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(TaskTreePickerSheet), findsOneWidget);

    // 选中项祖先路径自动展开 → A1 可见且带勾选 → 再点取消勾选
    // 注意：审核页按钮也显示"子任务A1"，用 descendant 限定树选择器内节点
    final treeNode = find.descendant(
      of: find.byType(TaskTreePickerSheet),
      matching: find.text('子任务A1'),
    );
    await tester.tap(treeNode);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byIcon(Icons.check_circle_rounded), findsNothing);
    await tester.tap(find.text('完成'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final updated = (await repository.getPendingReview()).single;
    expect(updated.parentTaskId, isNull);
    expect(TaskTreePickerSheet.clearSelection.id, '__clear__');
    await teardownTree(tester);
  });

  testWidgets('切换项目 → 失效父任务一并清除', (tester) async {
    final draft = await seedDraft(projectId: 'p1');
    await repository.updateDraft(draft.id, parentTaskId: 'A1');
    await pumpReviewSheet(tester);
    expect(find.text('子任务A1'), findsOneWidget);

    // 项目下拉切到 p2（p2 下无父任务候选）；菜单文本为 "未分组 / 项目B"
    await tester.tap(find.byType(DropdownButton<String?>).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('未分组 / 项目B').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final updated = (await repository.getPendingReview()).single;
    expect(updated.projectId, 'p2');
    expect(updated.parentTaskId, isNull); // 失效父任务已清除
    await teardownTree(tester);
  });
}
