# Design: fix-widget-test-and-package-windows

## Current State
`test/widget_test.dart` imports `MyApp` directly, pumps it, and asserts for the Flutter counter sample UI. Current `MyApp` constructs services that read `Supabase.instance`, so tests must initialize Supabase first. The actual unauthenticated app surface is the login page, not a counter.

## Approach
- Add test setup that calls `TestWidgetsFlutterBinding.ensureInitialized()` and `Supabase.initialize(...)` using the app constants.
- Change the smoke test to assert the unauthenticated login screen required by the smart-butler spec.
- Build the Windows release target with Flutter.
- Package the release directory into a zip artifact.

## Business Rule Handling
- Existing Requirement / Scenario: unauthenticated users see the login page.
- Handling: test fixture and packaging only; no app behavior change.

## Historical BugFixSpecs
- Hit files: none found under `openspec/bugfixspecs`.
- Historical root cause: none.
- Prevention check: widget tests that pump `MyApp` must initialize global SDKs used by app-level providers.

## Bug Root Cause Analysis
- User-visible symptom: tests fail and block packaging confidence.
- Failure layer: test initialization and stale generated sample test.
- Root cause: test harness did not initialize Supabase and still asserted default counter UI.
- Excluded causes: `MyApp` itself is initialized correctly in production `main()`.

## Regression Test Plan
- Case file: `regression-tests/cases/fix-widget-test-and-package-windows.md`
- Commands: `flutter test`, `flutter build windows --release`
- Expected output: tests pass; Windows release build exists and is zipped.

## Rollback
Revert `test/widget_test.dart` and delete the generated Windows package artifact.
