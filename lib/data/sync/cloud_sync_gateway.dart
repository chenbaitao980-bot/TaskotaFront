/// 云同步网关抽象口子（prd Decision 3 / Final Architecture）。
///
/// 业务层只依赖此接口，不直接碰 Supabase。当前实现 `LocalOnlyCloudSyncGateway`
/// （同步全部 no-op + 快照导出/导入可用）；将来 `AliyunCloudSyncGateway` 实现
/// 同一接口即可切换云端，业务零改动。
abstract class CloudSyncGateway {
  /// 全量对账（LWW）。本地为唯一真源时 no-op；云端实现为"拉远端合并 + 推本地更新"。
  Future<void> syncAll({bool forcePush = false});

  /// 纯拉取远端并合并到本地（不推送本地）。
  Future<void> pullAll();

  /// 实时订阅远端变更（本地实现 no-op）。
  void subscribe();

  void unsubscribe();

  /// 导出全库业务数据快照（JSON），作为备份/迁移到云端的桥（Decision 4）。
  Future<String> exportSnapshot();

  /// 从快照恢复/导入全库业务数据（按主键 upsert 合并）。
  Future<void> importSnapshot(String payload);
}
