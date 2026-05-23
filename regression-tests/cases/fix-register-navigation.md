# Regression Cases: fix-register-navigation

## Batch Test Endpoint
- command_or_url: `flutter analyze`
- auth: local mock mode or Supabase mode depending on `AppConstants.supabaseUrl`
- env: Flutter desktop/web development environment

## Cases
| case_id | Target | Input Summary | Expected Key Output | Assertion | Source | Status |
|---|---|---|---|---|---|---|
| register-success-navigates-home | Successful registration route response | valid email, matching password >= 6 chars, terms accepted | authenticated state leads to home route | manual/ui contains home screen after click | bugfix | pending |
| register-validation-visible | Validation errors remain visible | empty fields or mismatched password | SnackBar explains validation failure | manual/ui contains SnackBar | spec | covered by unchanged code path |

## Notes
- Do not store full credentials in this file.
- If an automated widget test is added later, bind it to `register-success-navigates-home`.
