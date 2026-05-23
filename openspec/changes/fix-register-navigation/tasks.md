# Tasks: fix-register-navigation

## Implementation
- [x] 1. Add `BlocListener<AuthBloc, AuthState>` to `RegisterPage`.
- [x] 2. Navigate to home on `Authenticated` or `LocalAuthenticated`.
- [x] 3. Show `AuthError` as a SnackBar.

## Verification
- [x] Historical BugFixSpecs check completed or confirmed no hit.
- [x] `bugfix_count` recorded for this round.
- [x] Regression case maintained.
- [x] `flutter analyze`.
- [x] `gitnexus detect-changes --scope all -r smart-assistant`.
