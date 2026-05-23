# Regression Cases: mvp-core-features

## Batch Test Endpoint
- command_or_url: `flutter analyze` + `flutter build windows --release`
- auth: 无
- env: 本地 Windows 开发机，需要 Flutter 3.41.9+ 和 Visual Studio 2022 BuildTools

## Cases
| case_id | 目标 | 入参摘要 | 期望出参关键字段 | 断言 | 来源 | 状态 |
|---------|------|---------|-----------------|------|------|------|
| MVP-001 | flutter analyze 无 error | flutter analyze | 0 errors | equals | spec | pass |
| MVP-002 | Windows 构建成功 | flutter build windows --release | exit_code=0, exe 生成 | equals | spec | pass |
| MVP-003 | 首页按钮可交互 | 点击"新建"FAB 或"语音录入"卡片 | 弹出创建对话框或跳转 AI 对话页 | behavior | spec | pending |
| MVP-004 | 日历周/月切换 | 点击日历页 SegmentedButton | 周视图/月视图切换 | behavior | spec | pending |
| MVP-005 | 日历 CRUD | 新建→编辑→删除日程 | 日程正确保存/更新/删除 | behavior | spec | pending |
| MVP-006 | AI 对话调用 DeepSeek | 输入"你好" | 返回非空 AI 回复 | behavior | spec | pending |
| MVP-007 | 登录/注册可用 | 输入邮箱+密码 | 成功跳转首页 | behavior | spec | pending |
| MVP-008 | 未登录拦截 | 退出登录后重启 | 展示登录页 | behavior | spec | pending |

## Notes
- MVP-003 到 MVP-008 需要手动验证（UI 交互）
- MVP-001 和 MVP-002 为自动验证（编译/构建）
- DeepSeek API Key 已配置：sk-1923fb07640b45b8a0ab564192810321
- Supabase 尚未配置，认证使用本地模拟模式
