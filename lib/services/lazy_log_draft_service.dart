import 'dart:async';

import '../data/repositories/lazy_log_draft_repository.dart';
import '../models/assistant/assistant_models.dart';
import '../models/assistant/lazy_log_models.dart';
import '../models/assistant/lazy_log_review_models.dart';
import 'home_lazy_log_service.dart';

typedef LazyLogDraftBuilder =
    FutureOr<List<LazyLogDraftWrite>> Function(LazyLogResult result);

class LazyLogDraftService {
  final HomeLazyLogService _lazyLogService;
  final LazyLogDraftRepository _draftRepository;

  LazyLogDraftService({
    required HomeLazyLogService lazyLogService,
    required LazyLogDraftRepository draftRepository,
  }) : _lazyLogService = lazyLogService,
       _draftRepository = draftRepository;

  Future<void> structureIntoDrafts({
    required String runningDraftId,
    required String input,
    required AssistantModelConfig config,
    required String projectRoutingContext,
    required LazyLogDraftBuilder buildDrafts,
    void Function(String error)? onError,
  }) async {
    try {
      final result = await _lazyLogService.structure(
        config: config,
        input: input,
        projectRoutingContext: projectRoutingContext,
      );
      if (result.isEmpty) {
        await _draftRepository.markFailed(runningDraftId, '没有整理出可创建的内容');
        return;
      }
      final drafts = await buildDrafts(result);
      if (drafts.isEmpty) {
        await _draftRepository.markFailed(runningDraftId, '没有可审核的任务草稿');
        return;
      }
      await _draftRepository.replaceRunningWithDrafts(
        runningId: runningDraftId,
        drafts: drafts,
      );
    } catch (error) {
      await _draftRepository.markFailed(runningDraftId, error.toString());
      onError?.call(error.toString());
    }
  }
}
