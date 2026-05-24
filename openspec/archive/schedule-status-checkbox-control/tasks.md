# 任务：schedule-status-checkbox-control

## 实施
- [x] 1. Schedule 模型新增 `status` 字段（默认 `in_progress`，可选 `completed`）
- [x] 2. 运行 `dart run build_runner build --delete-conflicting-outputs` 重新生成 freezed
- [x] 3. 首页日程列表 leading 改为 Checkbox
- [x] 4. 日历周视图事件块添加 compact Checkbox
- [x] 5. 日历事件列表 leading 改为 Checkbox
- [x] 6. 主 spec 追加状态控制 Scenario + 打包 Scenario
- [x] 7. project.md 追加打包约束

## 验证
- [x] 历史 BugFixSpecs 命中的防复发检查项已执行或确认无命中
- [x] 已维护本 change 的回归测试用例
- [x] `flutter analyze` 无 error（7 info/warning，含旧的 deprecation + _priorityColor 清理）
- [x] `flutter test` 通过
- [x] `flutter clean && flutter build windows --release` 通过 (95.0s)
- [x] `gitnexus detect-changes --scope all -r smart-assistant` (17 files, 34 symbols, 3 processes, Risk medium)
