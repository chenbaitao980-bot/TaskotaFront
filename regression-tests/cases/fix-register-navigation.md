# Regression Cases: fix-register-navigation

## Batch Test Endpoint
- command_or_url: `flutter analyze`
- auth: local mock mode or Supabase mode depending on `AppConstants.supabaseUrl`
- env: Flutter desktop/web development environment

## Cases
| case_id | Target | Input Summary | Expected Key Output | Assertion | Source | Status |
|---|---|---|---|---|---|---|
| register-success-navigates-home | Successful registration route response | valid email, matching password >= 6 chars, terms accepted | Supabase branch calls sign-up and authenticated state leads to home route | manual/ui contains home screen after click | bugfix | pending |
| register-does-not-sign-in-new-user | Supabase register path | new email/password in Supabase mode | no `Invalid login credentials` from login endpoint | manual/ui does not show invalid_credentials | bugfix | pending |
| register-validation-visible | Validation errors remain visible | empty fields or mismatched password | SnackBar explains validation failure | manual/ui contains SnackBar | spec | covered by unchanged code path |
| auth-errors-localized | Supabase auth failure feedback | invalid credentials or already registered email | Chinese message, no raw `AuthApiException(...)` | manual/ui contains localized SnackBar | bugfix | pending |
| auth-loading-visible | Supabase auth request loading | click login/register | button remains disabled and shows spinner while `AuthLoading` | manual/ui observes spinner during request | bugfix | pending |
| login-invalid-credentials | Failed login stays on login page | `574658212@qq.com` / supplied password when Supabase returns `invalid_credentials` | clear Chinese error and no home navigation | manual/ui remains login | user | pending |

## Notes
- Do not store full credentials in this file.
- If an automated widget test is added later, bind it to `register-success-navigates-home`.
