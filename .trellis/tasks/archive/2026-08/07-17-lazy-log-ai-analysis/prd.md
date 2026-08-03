# brainstorm: lazy log AI auth error notification

## Goal

懒人日志输入后按回车，AI 分析触发时如果 Token 过期（401/403），用户应该收到明确的报错提示引导重新配置 AI。

## What I already know

- 回车 → `_submitLazyLog()` → `LazyLogDraftService.structureIntoDrafts()` → `HomeLazyLogService.structure()`
- `structure()` 的 `catch (_)` 会静默吞掉所有异常，回退到规则分词 `_fallback()`，用户无感知
- 401/403 应该透传而不是静默降级

## Changes Made

### File 1: `lib/services/home_lazy_log_service.dart`
- `catch (_)` → `catch (e)`
- 对 DioException 401/403 直接 `rethrow`
- 其他异常保持原 fallback 逻辑

### File 2: `lib/services/lazy_log_draft_service.dart`
- `structureIntoDrafts()` 新增可选参数 `void Function(String error)? onError`
- catch 块中调用 `onError?.call()` 让 UI 层可以响应

### File 3: `lib/presentation/pages/home/home_page.dart`
- 两个 `structureIntoDrafts()` 调用处（`_submitLazyLog` + `_retryLazyLogDraft`）均传入了 `onError` 回调
- 收到 auth error 时显示 SnackBar：'AI 配置认证失败（Token 可能已过期），请在设置中重新配置 AI 模型'

## Acceptance Criteria

- [ ] AI Token 过期时按回车，SnackBar 提示重新配置
- [ ] 重试失败的草稿时，SnackBar 同样生效
- [ ] 网络超时等其他异常不走 SnackBar，维持原有 fallback 行为

## Out of Scope

- 不添加「去设置」按钮（`showAppSnackBar` 不支持 action）
- 不修改测试（测试直接调用 `HomeLazyLogService`，401/403 场景用 mock Dio 即可覆盖）
