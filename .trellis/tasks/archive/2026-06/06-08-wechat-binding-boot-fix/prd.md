# 微信提醒绑定 + 启动流程修复

## Goal

接入 WxPusher 微信推送提醒绑定功能，修复 Web 启动流程，优化登录页体验。

## 完成内容

### Bug 修复
- **隐私协议按钮 Web 上转圈**：`main.dart` 重构为单次 `runApp`，`MyApp` 改为 `StatefulWidget` 内部管理隐私状态，消除 Web 上二次 `runApp` 导致 Future 挂起的问题
- **WxPusher 二维码接口 404**：原代码直接拼 GET URL，WxPusher 不支持；改为新建 `wechat-qr` Edge Function 通过 POST 调用 WxPusher API 获取二维码图片 URL
- **二维码套二维码**：WxPusher 返回的 `url` 是图片地址，用 `Image.network` 直接显示，不再用 `QrImageView` 重新编码

### 新功能
- 个人资料页新增「微信提醒」菜单入口
- 首次登录后弹引导卡片，引导未绑定用户完成微信绑定
- 登录页底部加微信绑定引导文案

### 基础设施
- 配置 `AppConstants.wxpusherAppToken`（AT_jdaZaaj5CLY9HY4LUJwGTxoLskK5XIa3）和 `wxpusherAppId`（128230）
- Supabase 写入 `WXPUSHER_APP_TOKEN` secret
- 部署 Edge Functions：`wxpusher-callback`（no-verify-jwt）、`wechat-binding`、`wechat-qr`
- 创建 `wechat_bindings` 表（含 RLS）

### 登录页优化
- 标题从「智能小助手」统一改为「Taskora」
- 移除手机验证码 tab（Supabase Phone Auth 需付费 SMS，暂不支持）

### Web 部署流程调整
- 触发分支：`main` → `source`
- 构建产物输出：`deploy` → `main`（Vercel 默认服务 `main`）
- 推送命令：`git push github master:source`

## Commits

- d2cdb6e feat(wechat): 接入微信提醒绑定入口 + 修复隐私协议按钮无响应
- f6c8cc2 fix(login): 隐藏手机验证码入口，统一标题为 Taskora
- eee6409 fix(boot): 修复 Web 上同意条款后一直转圈
- 4e44e17 feat(login): 登录页底部加微信提醒引导文案
- 2d72c06 ci: 构建产物输出到 main 分支，Vercel 直接服务 main
- 3a6535b fix(wechat): 修复二维码接口 404 + 改为服务端调用 WxPusher
- 6aa864d fix(wechat): 修复 _qrUrl 字段名引用错误
- 8021254 fix(wechat): 直接显示 WxPusher 返回的二维码图片
