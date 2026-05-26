# Delta: checklist-obsidian-link

## 与主规范关系
New Capability — 新建能力 `task-checklist-obsidian-link`

## 变更类型
MODIFIED

## 新增规则

### R1: 检查项 Obsidian URI 存储
- 每个检查项可关联零个或一个 Obsidian URI
- URI 以 `obsidian://` 协议开头
- 存储格式为完整 URI 字符串，如 `obsidian://open?vault=MyVault&file=notes/design.md`
- 存储字段 `obsidian_uri` TEXT NULLABLE，值为 null 表示未关联

### R2: 检查项 URI 关联方式
- 用户可通过长按检查项 → "关联 Obsidian" 菜单进入关联对话框
- 关联对话框支持两种输入方式:
  a) 结构化输入: Vault 名称 + 文件路径 + 可选标题
  b) 直接粘贴: 完整的 `obsidian://` URI
- 保存时校验 URI 格式（必须以 `obsidian://` 开头）
- 已关联的检查项可通过长按菜单 "移除关联" 取消绑定

### R3: 检查项 UI 展示
- 已关联 Obsidian 的检查项在标题右侧显示链接图标（📎 或 open_in_new）
- 点击图标触发 `obsidian://` URI 启动
- 未关联的检查项保持现有样式，无图标

### R4: Obsidian 启动
- Windows: `cmd /c start "" obsidian://...`
- macOS: `open obsidian://...`
- Linux: `xdg-open obsidian://...`
- 启动失败时 Toast 提示用户检查 Obsidian 安装状态

### R5: 标题定位
- 定位到标题使用 `obsidian://adv-uri` 协议的 `heading` 参数
- 此功能依赖社区插件 Advanced URI，未安装时降级为仅打开文件
- 首次使用标题定位功能时提示安装插件

## 不变更的规则
- 检查项创建、编辑标题、切换状态、删除等现有功能不变
- 任务其他属性（TaskInfoSection, SubtaskTreeSection）不受影响
