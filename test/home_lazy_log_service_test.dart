import 'package:flutter_test/flutter_test.dart';
import 'package:smart_assistant/models/assistant/assistant_models.dart';
import 'package:smart_assistant/models/assistant/lazy_log_models.dart';
import 'package:smart_assistant/services/home_lazy_log_service.dart';

void main() {
  test(
    'falls back to local structuring when model config is incomplete',
    () async {
      final result = await HomeLazyLogService().structure(
        config: const AssistantModelConfig(),
        input: '今天完成首页懒人日志；遇到模型配置问题；明天准备联调日程创建',
      );

      expect(result.usedFallback, isTrue);
      expect(result.completed, contains('今天完成首页懒人日志'));
      expect(result.blockers, contains('遇到模型配置问题'));
      expect(result.nextActions, contains('明天准备联调日程创建'));
      expect(result.tasks.single.title, contains('联调日程创建'));
    },
  );

  test('parses structured task and schedule drafts', () {
    final result = LazyLogResult.fromJson({
      'summary': '整理今日输入',
      'completed': ['完成输入面板'],
      'blockers': ['无'],
      'nextActions': ['联调'],
      'tasks': [
        {
          'title': '修复首页样式',
          'description': '检查移动端布局',
          'priority': 'P1',
          'dueTime': '2026-07-14T18:00:00',
        },
      ],
      'schedules': [
        {
          'title': '项目复盘',
          'priority': 'P2',
          'startTime': '2026-07-14T10:00:00',
          'endTime': '2026-07-14T11:00:00',
        },
      ],
    });

    expect(result.summary, '整理今日输入');
    expect(result.tasks.single.priority, 'P1');
    expect(result.tasks.single.dueTime?.hour, 18);
    expect(result.schedules.single.title, '项目复盘');
    expect(result.schedules.single.endTime.hour, 11);
  });
}
