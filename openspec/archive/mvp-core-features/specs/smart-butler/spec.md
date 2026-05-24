# Delta: mvp-core-features

## 与主规范关系
New Capability — 主规范（smart-butler/spec.md）为本 change 新建，所有 Requirement 和 Scenario 均为首次实现。

## 命中的主规范
- Capability: `smart-butler`
- Requirement: 全部 5 个 Requirement
- Scenario: 全部 Scenario

## 变更类型
ADDED — 首次实现 MVP 全部 6 项核心功能

## 业务冲突检查
| 维度 | 状态 |
|------|------|
| 主规范 Req 命中 | 语音/文字录入、日历视图、AI任务拆解、云端同步、用户注册登录 |
| 关系判断 | New Capability（首次实现） |
| 其他 active change 撞车 | 无（changes/ 目录已清空） |
| 冲突状态 | 无冲突 |
| 是否允许 ADDED | 是（无已有实现，基线 spec 同步建立） |
| 归档完整性 | ✅ |

## 原规则
无（首次实现业务功能。init-smart-butler 建立代码骨架但无业务逻辑）

## 新规则

### Requirement: 本地优先架构
系统 SHALL 在所有数据操作中采用本地优先策略：先写入本地存储，再尝试云端同步；云端不可用时功能不中断。

#### Scenario: 无网络使用
- WHEN 设备无网络连接
- THEN 日程和任务数据保存到本地 SharedPreferences
- AND 用户可正常使用全部功能
- AND 网络恢复后数据可同步到 Supabase

### Requirement: 语音输入 Windows 兼容
语音输入在 Windows 上 SHALL 有 graceful degradation：ASR 不可用时自动引导用户使用文字输入。

#### Scenario: Windows 语音不可用
- WHEN speech_to_text 初始化失败（Windows 无语音语言包）
- THEN 展示 SnackBar 提示"语音功能需要系统语音语言包支持"
- AND 自动切换到文字输入模式

## 改动明细
详见 proposal.md 和 design.md 中的完整文件列表和实现方案。

### supabase密码
Q2oNmuxaHXDBJFuM 
