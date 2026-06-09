# 后台白名单豁免功能：支付设置页新增白名单VIP管理

## Goal

在 `taskora-website` 后台管理系统（Astro）中增加"白名单豁免"管理功能：管理员可通过 UI 查询用户、将其加入白名单，白名单用户自动获得 VIP 权限（无需付费订阅）。同步更新 Flutter 客户端 `subscription_service.dart`，将硬编码白名单改为从 Supabase 动态读取。

## What I already know

**taskora-website（Astro 后台网站）**
* 后台路由在 `src/pages/admin/`，已有：支付配置（`payment.astro`）、会员管理（`members.astro`）、下载管理（`downloads.astro`）
* 统一的管理员鉴权：Bearer token → Supabase `/auth/v1/user` → 检查 `user_metadata.role === 'admin'`
* API 端点在 `src/pages/api/admin/`，服务端使用 `SERVICE_ROLE_KEY`（可安全查询 auth.users）
* 已有数据库表：`member_types`, `user_subscriptions`, `payment_orders`, `member_config_logs`（操作日志）
* RLS 策略：管理员（role=admin）对所有表有完全权限

**Flutter 客户端**
* 当前白名单：`subscription_service.dart:17` 硬编码 `static const _vipWhitelist = {'574658218@qq.com'}`
* `isVip` 逻辑：先查硬编码白名单，再查 `_cached` 订阅

## Assumptions (temporary)

* 白名单存储：新建 Supabase 表 `vip_whitelist`（存 email + user_id + 备注 + 创建时间）
* 按**邮箱**查询用户（通过 `SERVICE_ROLE_KEY` 查 `auth.users`）
* 新功能放在**现有页面**还是**新建页面**待确认

## Open Questions

* ~~Q1: 白名单管理入口~~ → **已决定：放在 `payment.astro`（支付配置页）新增 Section**
* ~~Q2: 用户查询方式~~ → **已决定：直接输入邮箱，不验证用户是否存在，写入即生效**
* ~~Q3: Flutter 客户端同步更新~~ → **已决定：同步更新，硬编码白名单改为 Supabase 动态读取**
* ~~Q4: 现有硬编码白名单邮箱~~ → **已决定：自动迁移（迁移脚本 INSERT），同时修复白名单用户无法导出的 bug**

## Requirements (evolving)

**后台网站（taskora-website）**
* 在 `payment.astro` 支付配置页新增"白名单豁免"Section
* 管理员输入邮箱，一键加入白名单，显示当前白名单列表
* 可从白名单移除用户
* 新增 API 端点 `/api/admin/whitelist`（GET/POST/DELETE），使用 `SERVICE_ROLE_KEY`
* 新建 Supabase 数据库表 `vip_whitelist`（email, note, created_at），含迁移脚本
* 迁移脚本自动 INSERT `574658218@qq.com`（现有硬编码白名单）

**Flutter 客户端（smart_assistant）**
* `subscription_service.dart` 的 `refresh()` 同时查 `vip_whitelist` 表（按当前用户 email）
* 新增 `_isWhitelisted` 字段，`isVip` 逻辑：先查白名单，再查订阅
* 修复 bug：`currentMemberConfig` 对白名单用户返回 `null`（走全功能默认允许分支），不走 free plan 配置
* 删除硬编码 `_vipWhitelist` 常量

## Acceptance Criteria (evolving)

* [ ] 管理员在 payment.astro 可添加邮箱到白名单
* [ ] 白名单列表展示正常，可删除
* [ ] Flutter App：白名单用户 `isVip=true`，且 `canExportData()` 返回 `true`
* [ ] Flutter App：付费订阅用户逻辑不受影响
* [ ] 硬编码 `574658218@qq.com` 自动迁移，行为与之前一致且导出功能修复

## Definition of Done

* 功能可用，白名单增删改查正常
* 白名单 isVip 逻辑与硬编码白名单兼容（迁移期可并存）
* 无敏感 key 暴露在客户端
* Dart lint / type check 通过

## Out of Scope (explicit)

* 待确认

## Spec Conflicts

* `admin_ops_page.dart` 明确说明"跨用户查询需要 service_role，客户端不保存 service_role"→ 白名单用户搜索需通过 Edge Function，不能直接在客户端查 auth.users

## Technical Notes

* `subscription_service.dart:17` — 硬编码白名单 `_vipWhitelist`
* `subscription_service.dart:27-30` — `isVip` 先查白名单再查缓存
* `admin_ops_page.dart:182-191` — `_buildAdminBoundary()` 明确指出跨用户操作边界
* Supabase 表：`user_subscriptions`, `allowed_users`（现有），`vip_whitelist`（待建）
* 管理员验证模式参考：`allowed_users` 表（已用于 personal_admin_site 的 RLS 策略）
