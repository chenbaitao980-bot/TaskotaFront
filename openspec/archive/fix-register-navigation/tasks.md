# Tasks: fix-register-navigation

## Implementation
- [x] 1. Add `BlocListener<AuthBloc, AuthState>` to `RegisterPage`.
- [x] 2. Navigate to home on `Authenticated` or `LocalAuthenticated`.
- [x] 3. Show `AuthError` as a SnackBar.
- [x] 4. Add `Registered` auth event and handle it with `SupabaseService.signUp()`.
- [x] 5. Dispatch `Registered` from the Supabase registration branch.
- [x] 6. Normalize Supabase auth errors into Chinese user-facing messages.
- [x] 7. Make login/register button loading follow `AuthLoading`.
- [x] 8. Show registration success feedback.
- [x] 9. Keep failed login on login page with a clear Chinese message.

## Verification
- [x] Historical BugFixSpecs check completed or confirmed no hit.
- [x] `bugfix_count` recorded for this round.
- [x] Regression case maintained.
- [x] `flutter analyze`.
- [x] `flutter test`.
- [x] `flutter build windows --release`.
- [x] `gitnexus detect-changes --scope all -r smart-assistant`.
