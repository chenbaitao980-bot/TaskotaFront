# Regression Cases: fix-widget-test-and-package-windows

## Batch Test Endpoint
- command_or_url: `flutter test`; `flutter build windows --release`
- auth: Supabase initialized with app constants in test setup
- env: Flutter Windows development environment

## Cases
| case_id | Target | Input Summary | Expected Key Output | Assertion | Source | Status |
|---|---|---|---|---|---|---|
| widget-smoke-login-screen | MyApp unauthenticated smoke test | pump `MyApp` after Supabase initialization | login screen is visible | `flutter test` passes | bugfix | pending |
| windows-release-build | Windows packaging | run release build and zip release folder | zip artifact exists | command success and file exists | user | pending |

## Notes
- Do not record secrets beyond referencing existing app constants.
- Packaging output can be regenerated and should not be treated as source logic.
