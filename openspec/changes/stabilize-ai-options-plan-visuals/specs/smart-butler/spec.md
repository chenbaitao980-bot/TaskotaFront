# Delta: stabilize-ai-options-plan-visuals

## Relation To Main Spec
MODIFIED behavior under existing capability `smart-butler`.

## Requirement: AI任务拆解

### Scenario: AI question always offers relevant options
- WHEN the AI assistant asks a follow-up question during task planning
- THEN the UI SHALL display selectable options relevant to that exact question
- AND the options SHALL come from the assistant response when structured options are present
- AND if structured options are absent, the UI SHALL provide deterministic fallback options based on the current question stage
- AND the UI SHALL NOT reuse options from a previous question or unrelated keyword match.

### Scenario: Weekly plan renders as screenshot-aligned table
- WHEN the AI assistant returns a weekly learning or training plan
- THEN the final plan view SHALL render a table-style overview with date/day, theme, and training/content columns
- AND the table SHALL preserve day-by-day order
- AND the table SHALL remain readable on desktop and narrow windows without text overlap.

### Scenario: Plan process renders as screenshot-aligned flowchart
- WHEN the AI assistant returns a staged plan or learning process
- THEN the final plan view SHALL render colored rounded flow nodes connected by directional arrows
- AND the flowchart SHALL support horizontal and wrapped layouts as needed by available width
- AND the view SHALL render supporting checklist, key-point callout, and progress bar sections when provided by the AI output.
