# Delivery: fix-schedule-create-feedback

## Changed
- Home now builds its `IndexedStack` pages from current state instead of cached `_pages`.
- Home schedule creation ensures local storage is ready before saving.
- Calendar schedule creation ensures local storage is ready before saving.
- Home and Calendar now show `日程已创建` after a successful save.
- Home and Calendar now show `创建日程失败：...` if saving or reminder scheduling fails.
- Windows release zip was refreshed.

## Verification
- `dart format lib\presentation\pages\home\home_page.dart lib\presentation\pages\calendar\calendar_page.dart`: passed.
- `flutter test`: passed.
- `flutter build windows --release`: passed.
- `flutter analyze`: completed with 6 existing deprecated API info messages.
- `gitnexus detect-changes --scope all -r smart-assistant`: passed with LOW risk and 0 affected processes.
- Zip artifact: `E:\claude\project2\smart_assistant\smart_assistant_windows_release.zip`

## Notes
- This change keeps the current local-storage schedule path.
- It does not alter the schedule model or Supabase schedule synchronization behavior.
