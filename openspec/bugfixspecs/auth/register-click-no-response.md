# register-click-no-response: 注册按钮点击无响应

## 适用范围
- Capability: auth
- 关联 change: fix-register-navigation
- 关联文件/函数: `lib/presentation/pages/auth/register_page.dart` / `_register()`, `lib/presentation/blocs/auth/auth_bloc.dart`, `lib/presentation/blocs/auth/auth_event.dart`, `lib/presentation/pages/auth/login_page.dart` / `_login()`

## 用户可见现象
- 第1次：点击注册按钮后没有任何可见反应，注册成功但不跳转首页
- 第2次：点击注册后 Supabase 报错 `Invalid login credentials`（注册分支错误调用了登录 API）
- 第3次：注册错误信息显示为英文原始异常文本、注册成功无提示、按钮加载指示器不一致

## 根本原因
多层复合 bug，逐轮暴露：
1. `RegisterPage` 缺少 `BlocListener<AuthBloc, AuthState>`，注册成功触发了 auth state 变化但没有监听器响应
2. Supabase 注册分支错误 dispatch `LoggedIn` 事件，`AuthBloc` 将其映射到 `signInWithPassword`（登录 API），新用户未注册就被当作登录
3. 本地 `_isLoading` 标志在 dispatch bloc 事件后立即重置，而 Supabase 异步请求仍在进行；错误消息展示的是原生 `e.toString()` 字符串

## 为什么会反复修不好
- **缺层问题**：每一轮修复只解决了用户反馈的可见现象，没有全链路检查 auth flow 的 `写入 → 事件 → 状态 → UI 响应` 完整数据生命周期
- **登录/注册不对称**：Login 和 Register 页面各自维护独立的交互模式，同一套 auth 状态却由两套不同的监听逻辑处理
- **Supabase 模式 vs 本地模式分叉**：两条代码路径的行为不一致，修复本地模式不影响 Supabase 模式

## 正确修复模型
- 注册和登录两个入口应该共享同一套 auth 状态响应模板：`Authenticated/LocalAuthenticated → 导航首页`、`AuthError → 中文 SnackBar`、`AuthLoading → 按钮禁用+spinner`
- Supabase 注册必须走 `signUp()` 而非 `signInWithPassword()`
- 错误消息统一由 `AuthBloc` 归一化为中文，不应暴露原始 API 异常文本
- 加载状态必须跟随 `AuthBloc` 的 `AuthLoading` 状态，不能用本地标志

## 禁止做法
- 不要在 RegisterPage 中复用 `LoggedIn` 事件处理 Supabase 注册
- 不要在按钮 `onPressed` 中使用本地 `_isLoading` 作为加载指示器，必须跟随 `AuthBloc.state is AuthLoading`
- 不要直接向用户展示 `e.toString()` 或 `AuthApiException` 原始文本
- 不要在只收到一个层面反馈后就关闭诊断，必须检查同一 auth flow 的所有入口

## 防复发检查项
- [ ] 所有 auth 操作入口（login/register/logout）都使用相同的状态响应模式
- [ ] Supabase 注册分支 dispatch 的是专用注册事件，不是登录事件
- [ ] 加载指示器绑定 `AuthBloc.state is AuthLoading`
- [ ] 错误消息全部中文化，在 `AuthBloc` 中统一归一化
- [ ] 注册成功后有可见的反馈提示

## 最小验证集
```bash
# 1. 本地注册：输入邮箱+密码→注册→应直接跳转首页（非停留在注册页）
# 2. Supabase 注册：输入未注册邮箱+密码→注册→应创建账号并跳转首页
# 3. 错误处理：无效输入→应显示中文错误提示，非英文异常文本
# 4. 加载状态：点击注册按钮→按钮应显示 spinner 直到 auth 完成

flutter test
flutter build windows --release
```

## 相关历史
| change | bugfix_count | 归档时间 |
|---|---:|---|
| fix-register-navigation | 3 | 2026-05-23 |
