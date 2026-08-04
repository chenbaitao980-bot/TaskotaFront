/// 数据后端开关（prd Decision 4）：local | cloud，默认 local。
/// 业务层据此决定走本地 drift（唯一真源）还是云同步网关。
enum DataBackend { local, cloud }

class DataBackendConfig {
  DataBackendConfig._();

  /// 当前数据后端，默认 local（唯一真源为本地 drift）。
  static DataBackend current = DataBackend.local;
}
