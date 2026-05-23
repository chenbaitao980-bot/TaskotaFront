# Tasks: fix-widget-test-and-package-windows

## Implementation
- [x] 1. Initialize Supabase in the widget test setup.
- [x] 2. Replace stale counter assertions with current login screen assertions.
- [x] 3. Build Windows release package.
- [x] 4. Create a zip archive for the Windows release.

## Verification
- [x] Historical BugFixSpecs check completed or confirmed no hit.
- [x] `bugfix_count` recorded for this round.
- [x] Regression case maintained.
- [x] `dart format test/widget_test.dart`.
- [x] `flutter test`.
- [x] `flutter build windows --release`.
- [x] Windows zip artifact exists.
- [x] `gitnexus detect-changes --scope all -r smart-assistant`.
