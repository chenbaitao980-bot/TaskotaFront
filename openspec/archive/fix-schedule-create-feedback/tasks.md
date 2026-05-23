# Tasks: fix-schedule-create-feedback

## Implementation
- [x] 1. Rebuild Home indexed pages from current state instead of stale cached `_pages`.
- [x] 2. Ensure storage initialization before Home schedule creation.
- [x] 3. Add Home schedule creation success/error feedback.
- [x] 4. Ensure storage initialization before Calendar schedule creation.
- [x] 5. Add Calendar schedule creation success/error feedback.

## Verification
- [x] Historical BugFixSpecs check completed or confirmed no hit.
- [x] `bugfix_count` recorded for this round.
- [x] Regression case maintained.
- [x] `dart format`.
- [x] `flutter test`.
- [x] `flutter build windows --release`.
- [x] `gitnexus detect-changes --scope all -r smart-assistant`.
