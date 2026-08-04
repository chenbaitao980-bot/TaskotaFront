// 性能契约测试: P1-C 懒构建 _LazyIndexedPage（bf3e1cb 工作树）
// 原 bug: IndexedStack 首帧会 build 全部 children（tab0 首页/tab1 任务/tab2 日历/tab3 助手/tab4 我的），
//   首帧构建 5 个页面体拖慢启动；懒加载"切到才构建"被整列表 build 破坏
// 修复方式: _LazyIndexedPage 用 ValueNotifier tabIndex 监听 + 首次选中才 widget.builder 构建，
//   之后 _child 缓存复用不重建；未选中返回 SizedBox.shrink() 不占位构建
// 本测试用 dart:io 读源文件做结构不变量断言（私有 Widget 无法无头实例化）
// Layer: GENERATED
// TestedSource: _LazyIndexedPage + _LazyIndexedPageState@bf3e1cb072553db828e25b7fd3b67fdc2e61b50d

// === 必问三答 ===
// Q1: 触发条件是什么？
// A1: _buildPages 构建 5 个 tab 的 IndexedStack children；tab2/3/4 由 _LazyIndexedPage 包装
// Q2: 旧代码在这条件下会怎样？
// A2: IndexedStack 首帧 build 全部 children → 5 个页面体同时构建，首帧慢
// Q3: 新代码在这条件下会怎样？
// A3: tabIndex 首次切到自身 index 才 widget.builder 构建，之后 _child 缓存复用；未选中 shrink
//
// === 入参/出参标准 ===
// 入参: lib/presentation/pages/home/home_page.dart（当前工作树）
// 出参: 结构断言 — 类声明 / tabIndex+builder+_child 字段 / _maybeBuild 双守卫 /
//       build 返回 shrink / _buildPages 用 _LazyIndexedPage( 包装 3 处（tab2/3/4）

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final home =
      File('lib/presentation/pages/home/home_page.dart').readAsStringSync();

  // 活动代码行 = 非注释行（R-G-R 红验证注释活动行时测试必须能区分）
  List<String> activeLines(String marker, [String? haystack]) {
    final src = haystack ?? home;
    return src
        .split('\n')
        .where((l) => l.contains(marker) && !l.trimLeft().startsWith('//'))
        .toList();
  }

  group('P1-C _LazyIndexedPage 类结构', () {
    test('类声明存在（StatefulWidget + State）', () {
      expect(activeLines('class _LazyIndexedPage extends StatefulWidget'),
          isNotEmpty, reason: '_LazyIndexedPage 类声明缺失');
      expect(
          activeLines(
              'class _LazyIndexedPageState extends State<_LazyIndexedPage>'),
          isNotEmpty,
          reason: '_LazyIndexedPageState 类声明缺失');
    });

    test('tabIndex/builder 参数 + _child 缓存字段存在（活动代码）', () {
      expect(activeLines('final ValueNotifier<int> tabIndex;'), isNotEmpty,
          reason: 'tabIndex 参数缺失');
      expect(activeLines('final WidgetBuilder builder;'), isNotEmpty,
          reason: 'builder 参数缺失');
      expect(activeLines('Widget? _child;'), isNotEmpty,
          reason: '_child 缓存字段缺失');
    });
  });

  group('P1-C 懒构建守卫', () {
    // _maybeBuild 方法体：签名起至 setState 构建调用止，只含两个 return 守卫
    final maybeBuildBody = home
        .split('void _maybeBuild()')
        .last
        .split('setState(() => _child = widget.builder(context))')
        .first;

    test('非当前 tab 不构建（tabIndex.value != index 守卫）', () {
      expect(
          activeLines(
              'if (widget.tabIndex.value != widget.index) return;',
              maybeBuildBody),
          isNotEmpty,
          reason: '非当前 tab 懒构建守卫缺失');
    });

    test('已构建缓存复用（_child != null 守卫）', () {
      expect(activeLines('if (_child != null) return;', maybeBuildBody),
          isNotEmpty, reason: '缓存复用守卫缺失');
    });

    test('build 未选中时返回 SizedBox.shrink', () {
      expect(activeLines('return _child ?? const SizedBox.shrink();'),
          isNotEmpty, reason: '未选中 tab 未返回 shrink 占位');
    });
  });

  group('P1-C _buildPages 包装', () {
    test('tab2/3/4 用 _LazyIndexedPage( 包装（3 处）', () {
      expect(activeLines('child: _LazyIndexedPage(').length, 3,
          reason: '懒包装数量非 3（_LazyIndexedPage( 活动包装应为 tab2/3/4）');
    });
  });
}
// === 破坏性验证 ===
// 注释 home_page.dart:120 的 `if (widget.tabIndex.value != widget.index) return;` 后运行:
//   flutter test test_lazy_indexed_page.dart
// 预期: FAIL (AssertionError: 非当前 tab 懒构建守卫缺失)
// 恢复后: PASS
