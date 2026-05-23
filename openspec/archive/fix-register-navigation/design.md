# Design: fix-register-navigation

## Current State
`RegisterPage._register()` validates input and dispatches `LocalLogin` for local mode or `LoggedIn` for Supabase mode. `LoginPage` wraps its UI in `BlocListener<AuthBloc, AuthState>` and navigates on `Authenticated` or `LocalAuthenticated`, but `RegisterPage` does not listen to auth state changes. A successful registration can therefore update auth state without changing the visible page.

## Approach
Add the same auth-state response pattern to `RegisterPage`:
- On `Authenticated` or `LocalAuthenticated`, navigate to `AppRouter.home` with replacement.
- On `AuthError`, show the error in a SnackBar.
- Keep existing form validation, local storage registration, and loading state behavior unchanged.

Follow-up after user screenshot:
- Add a dedicated `Registered` auth event.
- Handle `Registered` in `AuthBloc` by calling `SupabaseService.signUp()`.
- Dispatch `Registered` from the Supabase branch in `RegisterPage`, instead of reusing `LoggedIn`.

Third-round fix after live account feedback:
- Stop treating raw `AuthApiException(...)` strings as user-facing text.
- Normalize common Supabase auth errors into Chinese messages.
- Drive login/register button loading from `AuthLoading`, not only from local `_isLoading`, so Supabase async requests keep the button spinner visible.
- Show a visible registration-success prompt before or during navigation.
- Make failed login leave the user on the login page with a clear message such as "邮箱或密码错误，或账号尚未注册".

## Business Rule Handling
- Existing Requirement / Scenario: user registration should create the account and navigate to the home page.
- Handling: code fix only; no business rule change.

## Historical BugFixSpecs
- Hit files: none found under `openspec/bugfixspecs`.
- Historical root cause: none.
- Prevention check: compare register flow with login flow so both react to successful auth states consistently.

## Bug Root Cause Analysis
- User-visible symptom: first no visible navigation, then `AuthApiException(message: Invalid login credentials, statusCode: 400, code: invalid_credentials)`, then English/raw error text and loading feedback gaps.
- Failure layer: UI state/routing response, incorrect auth event in the Supabase registration branch, and unnormalized auth feedback.
- Root cause: registration initially did not listen to auth success; after that was fixed, the Supabase branch still dispatched `LoggedIn`; after that was fixed, UI still used local loading flags that do not track bloc async work and displayed raw Supabase exception strings.
- Excluded causes: button `onPressed` exists; static analysis reports no register-page compile errors; `SupabaseService.signUp()` already exists.

## Data Lifecycle
Write chain: user taps register -> `_register()` validates form -> local storage or Supabase branch selected -> local branch dispatches `LocalLogin`, Supabase branch dispatches `Registered` -> `AuthBloc` emits `AuthLoading` -> calls `signUp()` -> emits success or normalized error -> page shows visible loading/success/error feedback -> success navigates.

Read/render chain: current route remains register page -> auth state changes in bloc -> page listener should observe state -> route replacement renders home page.

## Regression Test Plan
- Case file: `regression-tests/cases/fix-register-navigation.md`
- Command: `flutter analyze` plus targeted manual/UI verification.
- Inputs: valid email, matching password, accepted terms.
- Expected output: home page is shown after successful registration.

## Rollback
Revert the `RegisterPage` listener addition and remove this change's regression artifacts.
