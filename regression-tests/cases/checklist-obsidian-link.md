# 回归测试：checklist-obsidian-link

## 测试环境
- Windows 10/11
- Obsidian 已安装
- 至少一个 Obsidian Vault 存在

## 用例

### TC-01: 数据库升级兼容性
- **前置**: 已有 v2 数据库，含检查项数据
- **步骤**: 升级 App 到新版本（schema 2→3）
- **预期**: 所有已有数据完整，检查项 obsidianUri 字段为 null

### TC-02: 检查项创建时设置 Obsidian 链接
- **步骤**: 
  1. 创建新任务
  2. 添加检查项 "设计登录流程"
  3. 长按该检查项 → "关联 Obsidian"
  4. 输入 Vault: "MyVault", 文件: "设计/登录方案.md"
  5. 确认
- **预期**: 检查项右侧显示链接图标 📎

### TC-03: 结构化输入自动构建 URI
- **步骤**: 
  1. 关联对话框填 Vault: "MyKB", 文件: "notes/test.md"
  2. 不填标题
  3. 确认
- **预期**: 存储 URI = `obsidian://open?vault=MyKB&file=notes%2Ftest.md`

### TC-04: 结构化输入含标题
- **步骤**:
  1. 关联对话框填 Vault: "MyKB", 文件: "notes/test.md", 标题: "## 实现方案"
  2. 确认
- **预期**: 存储 URI 使用 adv-uri 协议，含 heading 参数

### TC-05: 粘贴完整 URI
- **步骤**:
  1. 在 Obsidian 中右键笔记 → "Copy Obsidian URL"
  2. 长按检查项 → "关联 Obsidian"
  3. 在 URI 输入框中粘贴
  4. 确认
- **预期**: 系统解析 URI 并回填结构化字段，存储完整 URI

### TC-06: 点击链接图标跳转
- **步骤**: 点击已关联检查项的 📎 图标
- **预期**: Obsidian 启动并打开对应文档，滚动到正确位置

### TC-07: 标题定位（Advanced URI）
- **前置**: Obsidian 已安装 Advanced URI 插件
- **步骤**: 点击含 heading 参数的检查项链接
- **预期**: Obsidian 打开文档并滚动到指定标题

### TC-08: 移除关联
- **步骤**: 
  1. 长按已关联检查项
  2. 选择 "移除关联"
  3. 确认
- **预期**: 链接图标消失，obsidianUri 为 null

### TC-09: 无效 URI 校验
- **步骤**: 在关联对话框中粘贴 "https://example.com"
- **预期**: 提示 "请输入有效的 Obsidian URI（以 obsidian:// 开头）"

### TC-10: Obsidian 未安装
- **前置**: 模拟 Obsidian 不可用
- **步骤**: 点击链接图标
- **预期**: Toast "无法打开 Obsidian，请确认已安装"

### TC-11: 无链接检查项不变
- **步骤**: 查看未关联 Obsidian 的检查项
- **预期**: 显示与当前版本一致，无额外图标
