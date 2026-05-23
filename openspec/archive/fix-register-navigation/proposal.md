# fix-register-navigation

## Why
Clicking the register button appears to do nothing after valid input. The expected behavior is that a successful registration authenticates the user and routes to the home page.

## Impact
GitNexus impact:
- `_register`: LOW risk, 0 direct upstream callers, 0 affected processes.
- `AuthBloc`: LOW risk, 2 direct upstream references from `lib/main.dart`, 0 affected processes.

## Business Spec Relationship
- Main spec: `openspec/specs/smart-butler/spec.md`
- Requirement: User registration and login
- Scenario: User registration
- Relationship: Bug Against Spec
- Action: Modify code only; business rule remains unchanged.

## Scope
- `lib/presentation/pages/auth/register_page.dart`
- Potentially related state listener behavior in `AuthBloc` usage only if required.

## Acceptance
- [ ] Valid local registration emits authenticated state and navigates to home.
- [ ] Valid Supabase-backed registration emits authenticated state and navigates to home.
- [ ] Registration validation errors still show visible SnackBars.
- [ ] Regression case maintained at `regression-tests/cases/fix-register-navigation.md`.
- [ ] `gitnexus detect-changes --scope all -r smart-assistant` reports only expected scope.

## Bug Fix Record
| bug_id | Symptom | First Seen | bugfix_count | Status |
|---|---|---|---:|---|
| register-click-no-response | Clicking register has no visible effect after successful registration | 2026-05-23 | 3 | open |

## Bug Trigger History
- Attempt 1: User reports "点击注册没有任何反应". Initial diagnosis indicates `RegisterPage` dispatches auth events but lacks the `BlocListener` navigation/error handling present on `LoginPage`.
- Attempt 2: User reports Supabase error `Invalid login credentials` during registration. Diagnosis indicates the Supabase registration branch dispatches `LoggedIn`, which calls `signInWithPassword`, instead of calling `signUp`.
- Attempt 3: User reports English error code display, no registration success prompt/loading, and login spinner disappears without entering the app. Direct Supabase password login check for the supplied account returns `invalid_credentials`.
