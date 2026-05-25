# 任务：fix-task-planning-over-fragmentation

## 实施
- [ ] 1. 修改 ai_service.dart System Prompt，增加时间范围请求类型和话题切换确认类型
- [ ] 2. 修改 ai_chat_page.dart，增加时间范围选择对话框
- [ ] 3. 修改 ai_chat_page.dart，增加话题切换确认对话框
- [ ] 4. 修改 ai_chat_page.dart，增加 AppBar 清空上下文按钮
- [ ] 5. 修改 ai_chat_page.dart _handleAIResponse()，根据 type 字段分发处理
- [ ] 6. 创建回归测试用例

## 验证
- [ ] <用户确认：用户输入"明天做西红柿炒蛋"，AI直接生成单日计划，不弹出时间选择框>
- [ ] <用户确认：用户输入"我想学做饭"，AI弹出时间范围选择框（1天内/1周内/1个月内/3个月内）>
- [ ] <用户确认：用户从"做饭"话题切换到"踢球"，AI弹出确认对话框，选择"开启新对话"后正常回复>
- [ ] <用户确认：点击 AppBar "清空上下文"按钮，确认后历史被清空>
