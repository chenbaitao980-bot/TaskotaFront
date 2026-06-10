# 模块隐藏与帮助/关于页面动态配置

## Goal

隐藏"运维后台"模块入口，并将"帮助与反馈"和"关于"两个页面的内容从硬编码改为从管理后台动态配置，提高运营灵活性。

## What I already know

### 当前架构

**运维后台入口：**
- `lib/presentation/pages/profile/profile_page.dart` 第 334-345 行，`_buildMenuSection()` 中直接注册了菜单项
- 目前无任何权限控制，任何能看到 ProfilePage 的用户都能访问
- 对应页面：`lib/presentation/pages/profile/admin_ops_page.dart`

**帮助与反馈页面：**
- `lib/presentation/pages/profile/help_feedback_page.dart`
- 内容完全硬编码：4 个"常用功能"项、3 个"常见问题"项、2 个"反馈方式"项
- 每个项包含 icon、title、body 三个字段

**关于页面：**
- `lib/presentation/pages/profile/about_page.dart`
- 内容完全硬编码：应用名称 "Taskora"、版本号 `_version = '1.0.0+3'`、3 条"核心能力"、3 条"数据与同步"、3 条"隐私与权限"

**已有的动态配置基础：**
- Supabase 已存在 `app_config` 表（key-value 结构：key TEXT, value TEXT, updated_at TIMESTAMPTZ），但 Flutter 端未使用
- `MemberConfigService` (`lib/services/member_config_service.dart`) 提供了最佳参考模式：远程加载 + SharedPreferences 本地缓存 + 后台刷新
- 已有关键值对式本地缓存模式（SharedPreferences）
- 已存在条件性 UI 显示模式 `_showLocalDataTools()` 方法

### Profile 页面菜单结构（`_buildMenuSection()`）
1. 开通VIP / VIP会员
2. 设置
3. 主题
4. 导出
5. **运维后台** ← 需要隐藏
6. **帮助与反馈** ← 需要动态化
7. **关于** ← 需要动态化
8. 退出登录

## 项目约定

* **"后台" = `E:\claude\project2\taskora-website`** — Astro + Starlight 文档站，已有完整 `/admin/` 管理后台
* Flutter App 与 taskora-website **共享同一个 Supabase 实例** (`wlehkvsxftyxmxelcaps`)
* `app_config` 表在此 Supabase 实例中已存在，Flutter 端和 Website 端均可访问

## Config 管理架构（已确认）

```
taskora-website (管理后台)  ──写入──→  Supabase app_config 表  ──读取──→  Flutter App (展示)
        ↑                                                                    ↑
   /admin/config (新增)                                           帮助与反馈 / 关于页面
```

* **写入端**: taskora-website 新增 `/admin/config` 管理页面（仿现有 admin CRUD 模式）
* **读取端**: Flutter App 新增 `AppConfigService`，从 Supabase 拉取 + SharedPreferences 缓存
* **数据流**: Website Admin → Supabase `app_config` → Flutter 读取 → 本地缓存 → UI 展示

## Assumptions (temporary)

* 运维后台需要完全隐藏（所有用户都看不到入口）
* 帮助与反馈和关于的内容通过 Supabase `app_config` 表动态拉取

### 已决策

* ✅ 配置格式：**多条 key-value**，每条记录对应一个内容块（section/item）
  * 示例 key 命名：`help.common.0.title`、`help.common.0.body`、`help.faq.0.title`、`about.core.0.body`
  * 管理后台逐条编辑，灵活度高
* ✅ 降级策略：**网络优先 + 缓存兜底 + 硬编码默认值**
  * 启动时异步从 Supabase 拉取 → 成功后写入 SharedPreferences 缓存
  * 网络失败 → 使用上次缓存数据
  * 缓存也为空 → 使用现有硬编码内容兜底
* ✅ 运维后台：**Flutter 端完全移除入口**，运维数据查看功能迁移到 taskora-website `/admin/` 面板

## Open Questions

（全部已解决）

## Requirements (evolving)

* 隐藏 ProfilePage 中的"运维后台"菜单入口
* 帮助与反馈页面内容从远程/本地配置动态加载
* 关于页面内容从远程/本地配置动态加载
* 提供配置管理入口

## Acceptance Criteria (evolving)

* [x] 普通用户看不到"运维后台"入口
* [x] 帮助与反馈页面展示的内容来自配置而非硬编码（缓存/网络未就绪时回退硬编码兜底）
* [x] 关于页面展示的内容来自配置而非硬编码（缓存/网络未就绪时回退硬编码兜底）
* [x] 网络不可用时帮助/关于页面仍能正常展示（缓存或默认值）

## Definition of Done (team quality bar)

* [x] Lint / typecheck 通过
* [x] 帮助与反馈、关于页面能正常展示配置内容
* [x] 降级方案验证通过（离线场景：缓存 → 硬编码默认值三级兜底）

## Out of Scope (explicit)

* 暂不涉及其他页面内容的动态化
* 暂不涉及底部 Tab 的动态配置

## Technical Notes

### 影响文件（Flutter App — smart_assistant）
- `lib/presentation/pages/profile/profile_page.dart` — 移除运维后台菜单项
- `lib/presentation/pages/profile/help_feedback_page.dart` — 重构为动态加载
- `lib/presentation/pages/profile/about_page.dart` — 重构为动态加载
- 新增：`lib/services/app_config_service.dart` — Supabase 配置读取 + SharedPreferences 缓存

### 影响文件（taskora-website — 管理后台）
- 新增：`src/pages/admin/config.astro` — 配置管理页面
- （可选）新增：`src/pages/api/admin/config.ts` — 配置 CRUD API

### 参考模式（Flutter）
- `lib/services/member_config_service.dart` — 远程配置 + 本地缓存 + 后台刷新的标准模式
- `lib/presentation/pages/profile/profile_page.dart` 中的 `_showLocalDataTools()` — 条件性 UI 显示模式

### 参考模式（taskora-website）
- `src/pages/admin/payment.astro` / `members.astro` — 现有 admin CRUD 页面模式
- `src/pages/api/admin/member-types.ts` — 现有 API 路由模式
- Supabase ANON key 已在 Website 客户端 script 中使用
