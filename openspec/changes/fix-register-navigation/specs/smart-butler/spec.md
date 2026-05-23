# Delta: fix-register-navigation

## Relationship To Main Spec
Bug Against Spec.

## Main Spec Hit
- Capability: `smart-butler`
- Requirement: User registration and login
- Scenario: User registration

## Change Type
Code fix only; business rule unchanged.

## Business Conflict Check
| Dimension | Status |
|---|---|
| Main spec requirement hit | User registration and login |
| Relationship | Bug Against Spec |
| Other active change collision | `mvp-core-features` also covers auth MVP; this fix narrows one registration routing bug and does not alter the requirement. |
| Conflict status | No blocking conflict found |
| ADDED allowed | No; existing capability is modified/fixed |
| Archive completeness | Pending implementation and verification |

## Original Rule
When a user enters email/password and clicks register, the system creates the account, creates a user profile record, and navigates to the home page.

## New Rule
No business rule change. The implementation must ensure successful registration visibly routes to the home page.

## Change Details
- File: `lib/presentation/pages/auth/register_page.dart`
- Location: `RegisterPage.build`
- Before: successful auth state can be emitted without route transition.
- After: register page reacts to successful auth state and replaces the current route with home.
