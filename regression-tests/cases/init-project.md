# Regression Cases: init-project

## Batch Test Endpoint
- command_or_url: `flutter analyze`（在项目根目录执行）
- auth: 无
- env: 本地 Windows 开发机，需要 Flutter 3.41.9+

## Cases
| case_id | 目标 | 入参摘要 | 期望出参关键字段 | 断言 | 来源 | 状态 |
|---------|------|---------|-----------------|------|------|------|
| INIT-001 | flutter analyze 无错误 | flutter analyze | No issues found | contains | spec | pass |
| INIT-002 | 核心目录结构存在 | 检查 lib/ 子目录 | core/, models/, presentation/, services/ 均存在 | exists | spec | pass |
| INIT-003 | pubspec.yaml 依赖可解析 | flutter pub get | exit_code=0 | equals | spec | pass |

## Notes
- init-project change 建立了项目骨架，后续 init-smart-butler 在此基础上补全了业务代码
