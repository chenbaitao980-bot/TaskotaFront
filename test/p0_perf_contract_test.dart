import 'package:flutter_test/flutter_test.dart';
import 'package:smart_assistant/data/sync/data_backend.dart';
import 'package:smart_assistant/services/supabase_service.dart';

void main() {
  test('契约5: Supabase 未初始化时 SupabaseService().currentUser 返回 null 不抛异常', () {
    // 无 Supabase.initialize：_client 字段初始化改为 getter 后构造不崩，
    // currentUser try/catch 捕获未初始化访问返回 null（走本地路径）。
    final svc = SupabaseService();
    expect(svc.currentUser, isNull);
  });

  test('契约3前置: DataBackendConfig 默认 local（断连决策），守卫条件成立', () {
    expect(DataBackendConfig.current, DataBackend.local);
  });
}
