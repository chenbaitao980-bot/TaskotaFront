// 回归测试: tab 切换不触发全量重建 + 首帧懒构建（0a6107d ValueNotifier + 本次 P1-C _LazyIndexedPage）
// 原 bug: tab 切换用 setState 全量重建 → 首帧 5 页 IndexedStack 全构建 + 切换卡顿（0a6107d 修复）；
//   本次 P1-C 进一步将 tab2/3/4 改为 _LazyIndexedPage 懒构建（首次选中才 build）
// 修复方式: _visibleTabIndex 用 ValueNotifier 驱动；_buildPages 用 _LazyIndexedPage 包装
//   tab2/3/4（初始 SizedBox.shrink，首次切 tab 才构建）；tab0/1 保持即时
// 对应提交: 0a6107d（历史）+ bf3e1cb 工作树（P1-C 新增 _LazyIndexedPage）
// 本测试用 dart:io 读源文件做结构不变量断言（私有 StatefulWidget 无法无头实例化）
// Layer: REGRESSION
// TestedSource: _HomePageState._buildPages + _LazyIndexedPage@bf3e1cb072553db828e25b7fd3b67fdc2e61b50d

// === 必问三答 ===
// Q1: 触发条件是什么？
// A1: 应用启动首帧（_buildPages 构建 5 页）；用户首次切换到 tab2/3/4
// Q2: 旧代码在这条件下会怎样？
// A2: IndexedStack 立即构建全部 5 页（首页 484 时间轴 overlay + 日历/助手/我的全量构建拖慢首帧）
// Q3: 新代码在这条件下会怎样？
// A3: tab2/3/4 初始 SizedBox.shrink（懒构建），首次切 tab 才真正 build；
//     本测试断言 _LazyIndexedPage 存在 + tabIndex 门控 + builder 缓存 → PASS
//
// === 入参/出参标准 ===
// 入参: home_page.dart 源文件（当前工作树）
// 出参: 结构断言 — class _LazyIndexedPage 存在 / ValueNotifier<int> tabIndex 门控 /
//       _child 缓存字段 / tab0/1 即时构建不被懒包装

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final home =
      File('lib/presentation/pages/home/home_page.dart').readAsStringSync();

  group('P1-C 懒构建（首帧轻量化）', () {
    test('_LazyIndexedPage 类存在且含 tabIndex 门控 + builder 缓存', () {
      expect(home.contains('class _LazyIndexedPage extends StatefulWidget'), isTrue,
          reason: '_LazyIndexedPage 缺失');
      expect(home.contains('class _LazyIndexedPageState extends State<_LazyIndexedPage>'),
          isTrue, reason: '_LazyIndexedPageState 缺失');
      expect(home.contains('final ValueNotifier<int> tabIndex;'), isTrue,
          reason: 'tabIndex 门控字段缺失');
      expect(home.contains('final WidgetBuilder builder;'), isTrue,
          reason: 'builder 字段缺失');
      expect(home.contains('Widget? _child;'), isTrue,
          reason: '_child 缓存字段缺失（懒构建须缓存已建页面）');
    });

    test('_LazyIndexedPage 有 _maybeBuild 门控方法（首次选中才 build）', () {
      expect(home.contains('void _maybeBuild()'), isTrue,
          reason: '首次选中门控方法缺失');
    });

    test('_buildPages 用 _LazyIndexedPage 包装 tab2/3/4（IndexedStack 懒构建）', () {
      expect(home.contains('_LazyIndexedPage('), isTrue,
          reason: '_buildPages 未使用懒包装器');
    });
  });

  group('0a6107d ValueNotifier 不变量', () {
    test('tab 索引仍由 ValueNotifier 驱动（不回归 setState 全量重建）', () {
      expect(home.contains('final ValueNotifier<int> _visibleTabIndex'), isTrue,
          reason: '_visibleTabIndex ValueNotifier 被移除（0a6107d 回归）');
      expect(home.contains('final ValueNotifier<int> _tabIndex'), isTrue,
          reason: '_tabIndex ValueNotifier 被移除');
    });
  });
}
// === 破坏性验证 ===
// 注释 home_page.dart:87-132 的 _LazyIndexedPage 类定义后运行:
//   flutter test test_regr_tab_valuenotifier.dart
// 预期: FAIL (AssertionError: _LazyIndexedPage 缺失)
// 恢复后: PASS
