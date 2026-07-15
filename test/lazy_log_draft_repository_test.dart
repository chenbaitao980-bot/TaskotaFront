import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_assistant/data/database/app_database.dart';
import 'package:smart_assistant/data/repositories/lazy_log_draft_repository.dart';
import 'package:smart_assistant/models/assistant/lazy_log_review_models.dart';

void main() {
  test(
    'running draft becomes reviewable drafts and approval hides it',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = LazyLogDraftRepository(database);

      final running = await repository.createRunning(
        sourceInput: '今天整理懒人日志',
        batchId: 'batch-1',
      );

      expect(await repository.watchRunningCount().first, 1);

      await repository.replaceRunningWithDrafts(
        runningId: running.id,
        drafts: [
          LazyLogDraftWrite(
            batchId: 'batch-1',
            sourceInput: '今天整理懒人日志',
            summary: '整理懒人日志',
            title: '完善懒人日志审核',
            description: '后台生成后进入审核列表',
            priority: 'P1',
            checklist: const ['生成草稿', '审核入库'],
            start: DateTime(2026, 7, 15, 9),
            end: DateTime(2026, 7, 15, 10),
            sortOrder: 0,
          ),
        ],
      );

      final reviewable = await repository.getPendingReview();
      expect(reviewable, hasLength(1));
      expect(reviewable.single.title, '完善懒人日志审核');
      expect(LazyLogDraftRepository.checklistOf(reviewable.single), [
        '生成草稿',
        '审核入库',
      ]);
      expect(await repository.watchPendingReviewCount().first, 1);

      await repository.approve(reviewable.single.id, createdTaskId: 'task-1');

      expect(await repository.getPendingReview(), isEmpty);
      expect(await repository.watchPendingReviewCount().first, 0);
    },
  );
}
