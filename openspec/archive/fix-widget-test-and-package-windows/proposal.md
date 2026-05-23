# fix-widget-test-and-package-windows

## Why
`flutter test` fails because the widget test still uses the default counter sample expectations and pumps `MyApp` without initializing Supabase. The user also needs a fresh Windows package after the test fix.

## Impact
GitNexus impact:
- `MyApp`: LOW risk, direct upstream reference from `test/widget_test.dart`.
- `test/widget_test.dart:main`: LOW risk, 0 upstream callers.

## Business Spec Relationship
- Main spec: `openspec/specs/smart-butler/spec.md`
- Requirement: User registration and login
- Scenario: Unauthenticated access
- Relationship: Bug Against Spec / test fixture gap
- Action: update test only; no business behavior change.

## Scope
- `test/widget_test.dart`
- Windows build output packaging under `build/windows/...` and a zip artifact.

## Acceptance
- [ ] Test initializes Supabase before pumping `MyApp`.
- [ ] Test expects the current unauthenticated login screen instead of the default counter UI.
- [ ] `flutter test` passes.
- [ ] Windows release build succeeds.
- [ ] Windows package zip is produced.
- [ ] `gitnexus detect-changes --scope all -r smart-assistant` is run.

## Bug Fix Record
| bug_id | Symptom | First Seen | bugfix_count | Status |
|---|---|---|---:|---|
| widget-test-supabase-not-initialized | `flutter test` fails: Supabase instance not initialized, then old counter assertions fail | 2026-05-23 | 1 | open |
