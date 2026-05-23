# BugFix Log: fix-widget-test-and-package-windows

## Bug Index

| bug_id | Symptom | Related files/symbols | bugfix_count | Status | Needs BugFixSpec |
|---|---|---|---:|---|---|
| widget-test-supabase-not-initialized | `flutter test` fails before app smoke assertions can pass | `test/widget_test.dart` / `MyApp` | 1 | open | No |

## Bug Events

### widget-test-supabase-not-initialized / Attempt 1
- Trigger time: 2026-05-23
- User symptom: MyApp test environment has not initialized Supabase; fix it, then package Windows.
- Reproduction path: run `flutter test`.
- Trigger conditions: widget test pumps `MyApp` directly without SDK initialization.
- Failed verification: assertion `_instance._isInitialized`; stale counter expectations then fail.
- Root-cause hypothesis: default generated widget test was not updated when app initialization changed.
- Final root cause: `test/widget_test.dart` pumped `MyApp` without initializing Supabase/shared preferences test storage and still asserted the default counter UI instead of the current login page.
- Fix points: `test/widget_test.dart`
- Verification result: `flutter test` passed.
- Same bug: yes; first recorded attempt.
