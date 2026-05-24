# Delta: fix-calendar-refresh-and-ai-options

## Relationship To Main Spec
Bug Against Spec: Calendar view and AI task breakdown already define the expected capabilities.

## Hit Main Spec
- Capability: `smart-butler`
- Requirement: `日历视图`
- Requirement: `AI任务拆解`
- Scenario: `查看周视图`, `日历上新建日程`, `目标拆解`

## Change Type
MODIFIED / bugfix only. Business rules are unchanged.

## Conflict Check
| Dimension | Status |
|---|---|
| Main spec requirement hit | Calendar view, AI task breakdown |
| Relationship | Bug Against Spec |
| Other active change collision | `claude-ui-and-progressive-ai`, `schedule-status-checkbox-control` |
| Conflict state | No behavior conflict; same files require careful scoped edits |
| ADDED allowed | No; existing requirements cover this |
| Archive completeness | pending |

## Old Rule
- Calendar view requires schedules to be visible in week/month views.
- AI task breakdown requires AI to ask necessary information and support suggested replies.

## New Rule
Business rule unchanged. Implementation must keep Calendar in sync after schedule writes from Home and convert explicit AI option protocol lines into clickable suggestion buttons.

## Change Details
- File: `lib/presentation/pages/home/home_page.dart`
  - Before: Home schedule writes refresh only Home stats.
  - After: Home schedule writes also notify Calendar state to reload.
- File: `lib/presentation/pages/calendar/calendar_page.dart`
  - Before: Calendar reloads events only during its own interactions.
  - After: Calendar reloads when Home passes a changed refresh signal.
- File: `lib/presentation/pages/ai_chat/ai_chat_page.dart`
  - Before: `[OPTIONS: ...]` remains in message text and is not clickable.
  - After: `[OPTIONS: ...]` is parsed into `suggestions`, removed from display text, and rendered as clickable chips.
