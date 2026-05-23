# Design: fix-register-navigation

## Current State
`RegisterPage._register()` validates input and dispatches `LocalLogin` for local mode or `LoggedIn` for Supabase mode. `LoginPage` wraps its UI in `BlocListener<AuthBloc, AuthState>` and navigates on `Authenticated` or `LocalAuthenticated`, but `RegisterPage` does not listen to auth state changes. A successful registration can therefore update auth state without changing the visible page.

## Approach
Add the same auth-state response pattern to `RegisterPage`:
- On `Authenticated` or `LocalAuthenticated`, navigate to `AppRouter.home` with replacement.
- On `AuthError`, show the error in a SnackBar.
- Keep existing form validation, local storage registration, and loading state behavior unchanged.

## Business Rule Handling
- Existing Requirement / Scenario: user registration should create the account and navigate to the home page.
- Handling: code fix only; no business rule change.

## Historical BugFixSpecs
- Hit files: none found under `openspec/bugfixspecs`.
- Historical root cause: none.
- Prevention check: compare register flow with login flow so both react to successful auth states consistently.

## Bug Root Cause Analysis
- User-visible symptom: clicking register has no visible effect.
- Failure layer: UI state/routing response after auth state change.
- Root cause: registration dispatches auth state changes but the register page does not subscribe to them, so success is not converted into navigation.
- Excluded causes: button `onPressed` exists; static analysis reports no register-page compile errors; local registration path dispatches `LocalLogin`.

## Data Lifecycle
Write chain: user taps register -> `_register()` validates form -> local storage or Supabase auth executes -> auth event is dispatched -> `AuthBloc` emits authenticated state -> register page should navigate.

Read/render chain: current route remains register page -> auth state changes in bloc -> page listener should observe state -> route replacement renders home page.

## Regression Test Plan
- Case file: `regression-tests/cases/fix-register-navigation.md`
- Command: `flutter analyze` plus targeted manual/UI verification.
- Inputs: valid email, matching password, accepted terms.
- Expected output: home page is shown after successful registration.

## Rollback
Revert the `RegisterPage` listener addition and remove this change's regression artifacts.
