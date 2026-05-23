# BugFix Log: fix-register-navigation

## Bug Index

| bug_id | Symptom | Related files/symbols | bugfix_count | Status | Needs BugFixSpec |
|---|---|---|---:|---|---|
| register-click-no-response | Clicking register has no visible effect, Supabase reports invalid login credentials, then auth feedback/loading remains unclear | `register_page.dart` / `_register` / `login_page.dart` / `_login` / `AuthBloc` | 3 | open | Yes |

## Bug Events

### register-click-no-response / Attempt 1
- Trigger time: 2026-05-23
- User symptom: "点击注册没有任何反应"
- Reproduction path: open register page, enter valid email/password, accept terms, click register.
- Trigger conditions: registration succeeds and auth state changes, but the current page does not react to that state.
- Failed verification: user sees no navigation or visible success result.
- Root-cause hypothesis: `RegisterPage` lacks the auth-state `BlocListener` already present on `LoginPage`.
- Final root cause: `RegisterPage` dispatched successful auth events but did not listen for `Authenticated` or `LocalAuthenticated`, so it never converted successful registration into route replacement.
- Fix points: `lib/presentation/pages/auth/register_page.dart`
- Verification result: `flutter analyze` completed with only pre-existing deprecated API info; `gitnexus detect-changes` completed and reported medium risk due to broad pre-existing workspace changes; `flutter test` is blocked by the existing default widget test requiring Supabase initialization and expecting the old counter UI.
- Same bug: yes; first recorded attempt.

### register-click-no-response / Attempt 2
- Trigger time: 2026-05-23
- User symptom: screenshot shows `AuthApiException(message: Invalid login credentials, statusCode: 400, code: invalid_credentials)` after clicking register.
- Reproduction path: open register page, enter a new email/password, accept terms, click register with real Supabase URL configured.
- Trigger conditions: Supabase mode is active.
- Failed verification: registration branch dispatches `LoggedIn`; `AuthBloc` calls `signInWithPassword`, so a new account is treated as a login attempt.
- Root-cause hypothesis: registration and login share the wrong auth event in the Supabase branch.
- Final root cause: Supabase registration branch used `LoggedIn` instead of a sign-up event; `SupabaseService.signUp()` existed but was not wired.
- Fix points: `lib/presentation/blocs/auth/auth_event.dart`, `lib/presentation/blocs/auth/auth_bloc.dart`, `lib/presentation/pages/auth/register_page.dart`
- Verification result: `flutter test` passed; `flutter build windows --release` passed; `flutter analyze` completed with only pre-existing deprecated API info.
- Same bug: yes; same page and same registration action chain as attempt 1.

### register-click-no-response / Attempt 3
- Trigger time: 2026-05-23
- User symptom: registration error is English/raw, registration success has no prompt, registration process has no persistent spinner, and login spins briefly but does not enter the app.
- Reproduction path: register or login with Supabase mode enabled; supplied login credentials `574658212@qq.com` / `ysydxhyz147` return `invalid_credentials` from the Supabase password token endpoint.
- Trigger conditions: Supabase auth request fails or is in flight.
- Failed verification: UI exposes raw backend exception text and loading state is decoupled from `AuthBloc` async processing.
- Root-cause hypothesis: local `_isLoading` is reset immediately after dispatching bloc events, while user-facing errors are raw `e.toString()` values from Supabase.
- Final root cause: Supabase auth failures were emitted as raw exception strings, and login/register buttons used local `_isLoading` that reset immediately after dispatching bloc events instead of following `AuthLoading`. The corrected account `574658218@qq.com` returns `email_not_confirmed`, so the app must show a clear Chinese email-verification message rather than appearing to do nothing.
- Fix points: `lib/presentation/blocs/auth/auth_bloc.dart`, `lib/presentation/pages/auth/login_page.dart`, `lib/presentation/pages/auth/register_page.dart`
- Verification result: `flutter test` passed; `flutter build windows --release` passed; `gitnexus detect-changes` passed with LOW risk and 0 affected processes; `flutter analyze` completed with only pre-existing deprecated API info.
- Same bug: yes; same auth entry flow and same successful/failed feedback chain as attempts 1 and 2.
