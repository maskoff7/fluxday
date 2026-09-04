# Legacy prototype audit

Source preserved verbatim at `reference/legacy/cashflow_planner.html`.

## Existing product

The prototype is a Russian-language, single-file browser application. It supports start balance/date settings; income and expense CRUD; certain and expected status; one-off, daily, weekly, monthly and yearly recurrence; a daily timeline; balance table and chart; Monday-first calendar; recurring-series list; week/month/year/custom summary; and scenario overrides for recurring operations. It compares the normal plan with a stress calculation that removes expected income while retaining every expense.

State shape is `{ settings, events, scenarios }`. Events contain `id`, `name`, decimal `amount`, `date`, `type`, `certainty`, `note`, `recurrence` and `repeatUntil`. Scenarios store sparse overrides by event id. Browser persistence uses `cashflow_planner_v2` (`v1` fallback); JSON export labels the format as version 3. A saved HTML copy embeds the same state.

## Calculation and date behaviour

- Occurrences are expanded up to a global horizon with a 5,000-item guard.
- Daily closing balance is start balance plus all same-day signed operations; the UI therefore avoids a false intraday gap caused by sort order.
- Stress balance includes all expenses and only certain income.
- Monthly recurrence uses the original day as the anchor, clamped to the target month's final day. Yearly recurrence similarly maps 29 February to 28 February when needed.
- Summary aggregates occurrences by source event and uses absolute amounts for its combined composition chart.

## UX patterns worth preserving

Fast inline creation, six primary views, explicit certainty badges, visible daily closing balance, plan/stress comparison, calendar month navigation, a dedicated recurring area, sparse scenario overrides, full operation names, local autosave, JSON portability and calm colour semantics are all valuable.

## Limitations and risks

- Money uses JavaScript floating point and can accumulate rounding error.
- `Date` uses local time and is vulnerable to timezone/DST edge cases.
- Browser local storage has weak durability, no migrations and no transactional recovery.
- Import commits immediately, has no preview, weak validation and no duplicate-ID report.
- Delete relies on modal confirmation rather than recoverable undo.
- Business logic, state, rendering and persistence live in one global script, making regression testing difficult.
- Inline HTML event handlers and broad DOM string rendering make accessibility and maintenance fragile.
- The fixed recurrence guard silently truncates exceptional ranges.
- Scenarios can reference removed operations; normalization drops some malformed data without reporting it.
- The prototype has no application lifecycle integration, native dialogs, database backup, CI or automated tests.

## Migration contract

Fluxday accepts both bare legacy state and versioned exports. Decimal legacy values are rounded once into integer minor units; dates and enums are validated; invalid rows are reported in preview; duplicate IDs are deterministically regenerated; and confirmation replaces the current plan, which makes repeating the same import idempotent. The original file remains untouched as historical evidence.
