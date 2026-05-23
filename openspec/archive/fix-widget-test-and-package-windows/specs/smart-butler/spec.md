# Delta: fix-widget-test-and-package-windows

## Relationship To Main Spec
Bug Against Spec / test fixture gap.

## Main Spec Hit
- Capability: `smart-butler`
- Requirement: User registration and login
- Scenario: Unauthenticated access

## Change Type
Code test fix only; business rule unchanged.

## Business Conflict Check
| Dimension | Status |
|---|---|
| Main spec requirement hit | User registration and login |
| Relationship | Test fixture for existing scenario |
| Other active change collision | `fix-register-navigation` touches register page; this change touches tests and package output |
| Conflict status | No blocking conflict found |
| ADDED allowed | No; existing capability is covered |
| Archive completeness | Pending verification |

## Original Rule
Unauthenticated users opening the app see the login page and are blocked from feature pages.

## New Rule
No business rule change. The widget smoke test must initialize Supabase and verify the current unauthenticated login surface.

## Change Details
- File: `test/widget_test.dart`
- Before: pumps `MyApp` without Supabase initialization and expects counter UI.
- After: initializes Supabase and expects the login screen.
