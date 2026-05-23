# 任务：smart-butler-core-intelligence

## 实施

### F7 用户画像构建
- [x] 1. `user_profile.dart`：已存在 explicitProfile/implicitProfile 字段
- [x] 2. `local_storage_service.dart`：新增 saveProfile/getProfile + onboarding flag
- [x] 3. `onboarding_page.dart`：新建3步问卷页面（基本信息→目标→水平）
- [x] 4. `home_page.dart`：首次启动检测 → 引导到 Onboarding
- [x] 5. `home_page.dart`：`_loadStats` 中自动更新隐式画像

### F8 个性化任务拆解
- [x] 6. `ai_service.dart`：system prompt 增加用户画像占位符 + _formatProfile
- [x] 7. `ai_chat_page.dart`：`_callAI` 前注入用户画像数据

### F9 冲突检测
- [x] 8. `local_storage_service.dart`：新增 `detectTimeConflict` 方法
- [x] 9. `ai_service.dart`：新增 `analyzeConflict` 冲突分析 AI 调用
- [ ] 10. `create_schedule_dialog.dart`/`home_page.dart`：创建日程时冲突检测→弹窗建议

### F10 动态提醒
- [x] 11. `notification_service.dart`：新增 `_urgencyScore` + 动态提醒逻辑
- [x] 12. `home_page.dart`：提醒调用已走 `NotificationService().scheduleReminderForSchedule`

## 验证
- [ ] 首次启动弹出3步Onboarding问卷
- [ ] AI拆解时引用用户画像数据（如"你当前水平是零基础..."）
- [ ] 时间冲突时弹出3选项建议对话框
- [ ] 高优先级任务提醒提前量大于低优先级
- [ ] `flutter analyze` 无 error
