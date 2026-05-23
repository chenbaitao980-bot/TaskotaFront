# Regression Cases: init-smart-butler

## Batch Test Endpoint
- command_or_url: `flutter analyze`（在项目根目录执行）
- auth: 无
- env: 本地 Windows 开发机，需要 Flutter 3.41.9+

## Cases
| case_id | 目标 | 入参摘要 | 期望出参关键字段 | 断言 | 来源 | 状态 |
|---------|------|---------|-----------------|------|------|------|
| BUTLER-001 | flutter analyze 无错误 | flutter analyze | No issues found | contains | spec | pass |
| BUTLER-002 | 数据模型文件存在 | 检查 lib/models/ | schedule.dart, task_breakdown.dart, user_profile.dart 等存在 | exists | spec | pass |
| BUTLER-003 | BLoC 文件存在 | 检查 lib/presentation/blocs/ | auth/, schedule/, task/, ai_chat/ 目录存在 | exists | spec | pass |
| BUTLER-004 | 路由配置可编译 | 检查 lib/core/router/app_router.dart | 文件存在且 analyze 无错误 | exists | spec | pass |
| BUTLER-005 | Windows Desktop 编译通过 | flutter build windows --release | exit_code=0 | equals | spec | pass |

## Notes
- init-smart-butler 在 init-project 骨架基础上补全了业务逻辑代码
