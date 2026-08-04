// 性能契约测试: P1-F cancelRepeats 降量（bf3e1cb 工作树）
// 原 bug: cancelReminderForSchedule 每任务取消 24 次平台通道调用（base + offset1 + 21 次 repeat），
//   批量重调度 rescheduleTaskReminders 对 115 任务 ×24 次 → ~6.4s 拖住首帧（白屏主因）
// 修复方式: cancelReminderForSchedule 加 {bool cancelRepeats=true}；批量重调度路径（任务侧
//   调用）传 cancelRepeats:false → 仅 2 次取消（base+offset1），跳过 21 次 repeat 循环；
//   单任务删除/停用仍传默认 true 全量取消。web 空实现签名同步
// 本测试用 dart:io 读源文件做结构不变量断言（NotificationService 依赖平台通道无法无头实例化）
// Layer: GENERATED
// TestedSource: NotificationService.cancelReminderForSchedule + NotificationService.rescheduleTaskReminders@bf3e1cb072553db828e25b7fd3b67fdc2e61b50d

// === 必问三答 ===
// Q1: 触发条件是什么？
// A1: 批量重调度路径调 cancelReminderForSchedule(id, cancelRepeats: false)；单任务删除调默认 true
// Q2: 旧代码在这条件下会怎样？
// A2: 无条件执行 21 次 repeat 取消循环（每任务 24 次通道调用），批量重调度时秒级阻塞
// Q3: 新代码在这条件下会怎样？
// A3: cancelRepeats:false → 取消 base+offset1 后 `if (!cancelRepeats) return;` 跳过循环（仅 2 次）；
//     默认 true 保持全量取消
//
// === 入参/出参标准 ===
// 入参: notification_service_io.dart + notification_service_web.dart 源文件
// 出参: 结构断言 — cancelRepeats 参数 / 守卫在 base+offset1 后且 repeat 循环前 /
//       批量重调度调用点传 false / web 签名同步

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final io = File('lib/services/notification_service_io.dart').readAsStringSync();
  final web = File('lib/services/notification_service_web.dart').readAsStringSync();

  // 活动代码行 = 非注释行（R-G-R 红验证注释活动行时测试必须能区分）
  List<String> activeLines(String marker, [String? haystack]) {
    final src = haystack ?? io;
    return src
        .split('\n')
        .where((l) => l.contains(marker) && !l.trimLeft().startsWith('//'))
        .toList();
  }

  group('P1-F cancelRepeats 折叠（io 实现）', () {
    test('cancelReminderForSchedule 含 cancelRepeats 参数（默认 true）', () {
      expect(activeLines('bool cancelRepeats = true,'), isNotEmpty,
          reason: 'cancelRepeats 参数缺失（活动代码）');
    });

    test('base+offset1 取消先于守卫，repeat 循环在守卫后', () {
      final body = io.split('Future<void> cancelReminderForSchedule').last;
      final baseIdx = body.indexOf('notificationIdForSchedule(scheduleId)');
      final offset1Idx =
          body.indexOf('notificationIdForSchedule(scheduleId, offset: 1)');
      // 守卫取活动行（过滤注释），确保 R-G-R 注释后守卫索引消失 → 排序断言失败
      final guardLines = body.split('\n').where((l) =>
          l.contains('if (!cancelRepeats) return;') &&
          !l.trimLeft().startsWith('//')).toList();
      final loopIdx = body.indexOf('_maxRepeatOccurrences');
      expect(baseIdx, greaterThan(-1), reason: 'base 取消缺失');
      expect(offset1Idx, greaterThan(-1), reason: 'offset1 取消缺失');
      expect(guardLines, isNotEmpty,
          reason: 'cancelRepeats 短路守卫缺失（活动代码）');
      expect(body.indexOf(guardLines.first), greaterThan(offset1Idx),
          reason: 'guard 须在 base+offset1 取消之后（先取消基础再短路）');
      expect(loopIdx, greaterThan(body.indexOf(guardLines.first)),
          reason: 'repeat 循环须在 guard 之后（skip 语义）');
    });

    test('批量重调度调用点传 cancelRepeats: false（降量调用点）', () {
      expect(
          activeLines('cancelReminderForSchedule(task.id, cancelRepeats: false)'),
          isNotEmpty,
          reason: '批量重调度路径未降量（活动代码）');
    });
  });

  group('web 空实现签名同步', () {
    test('web cancelReminderForSchedule 含 cancelRepeats 参数', () {
      expect(activeLines('bool cancelRepeats = true,', web), isNotEmpty,
          reason: 'web 签名未同步（web stub 兼容性破坏）');
    });
  });
}
// === 破坏性验证 ===
// 注释 notification_service_io.dart:893 的 `if (!cancelRepeats) return;` 后运行:
//   flutter test test_notification_cancel_contract.dart
// 预期: FAIL (AssertionError: cancelRepeats 短路守卫缺失（活动代码）)
// 恢复后: PASS
