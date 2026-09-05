# Financial algorithms

This document is the portable behavior specification for Fluxday. `CashFlowCore` implements it without SwiftUI, AppKit, Charts or persistence dependencies. Other native clients can use the rules and golden fixtures without sharing presentation code.

## Money

All stored and calculated monetary values are signed 64-bit integer minor units. For RUB, `12,345.67` is stored as `1234567`. User-entered operation amounts are limited to `10,000,000,000` minor units (100 million RUB), while aggregates use the full `Int64` range. Every forecast and summary addition or subtraction checks overflow and fails instead of wrapping or losing precision.

Floating-point values are never used for stored money or balance calculations. `Double` is allowed only for derived ratios such as a summary share.

## Calendar dates

Financial dates use the strict `YYYY-MM-DD` form and contain no time, time zone or timestamp. Valid years are 1000 through 9999 in the proleptic Gregorian calendar. Date arithmetic is deterministic and independent of daylight-saving transitions.

- A leap year is divisible by 4, except century years not divisible by 400.
- Adding months or years always uses the original anchor day and clamps it to the last valid day of the target month.
- Weeks start on Monday.
- A forecast contains at most 40,000 calendar days and cannot extend more than 100 years from its start date.

## Recurrence

An enabled operation can occur once or repeat daily, weekly, monthly or yearly. Both the requested range and `recurrenceEndDate` are inclusive. A missing end date repeats only through the requested forecast range.

Monthly occurrences are calculated as `firstDate + N months`, never `previousOccurrence + 1 month`. A series anchored on January 31 therefore produces February 28 or 29, March 31 and April 30 without drifting. A yearly series anchored on February 29 produces February 28 in non-leap years and returns to February 29 in the next leap year.

Expansion jumps close to the visible range before iterating, so an old daily or weekly series does not waste work on hidden occurrences. A single operation is limited to 50,000 expanded occurrences.

## Forecast and stress mode

For each day, Fluxday groups every occurrence and calculates:

```text
income = sum(income occurrences)
expense = sum(expense occurrences)
net = income - expense
closing balance = opening balance + net
stress closing balance = previous stress balance + net - expected income
```

Expected expenses remain in stress mode. Only income marked `expected` is removed. Minimum, maximum and negative-balance metrics use the closing balance after all operations on that day, so operation ordering cannot create a false intraday gap.

A cash gap is a consecutive run of days whose closing balance is negative. It records the first negative day, the lowest balance and date, the maximum deficit, and the first later non-negative recovery day. Recovery is absent when the balance remains negative through the forecast horizon.

## Scenarios

A scenario stores sparse overrides keyed by source operation ID. Overrides can change amount, recurrence, first date, recurrence end, certainty or exclusion. They apply only to recurring series and produce new operation values; the base plan is never mutated. An explicit JSON `null` recurrence end is distinct from an omitted override and removes the end date.

Scenario comparison calculates base and adjusted forecasts over the same dates, then reports exact ending- and minimum-balance deltas.

## Summaries

Summaries expand actual occurrences within an inclusive date range. Income, expense, net and turnover use checked minor-unit arithmetic. Visible occurrences are grouped by source operation, sorted by total descending, and assigned a derived share of the selected total.

## Portable JSON

The persisted plan retains the v0.1.0 field names and enum values. `startBalanceMinor`, `amountMinor` and scenario amount overrides encode as JSON integers; calendar dates encode as `YYYY-MM-DD` strings. Unknown export metadata such as `version`, `product` and `exportedAt` is ignored when decoding the plan.

The canonical compatibility fixture is [`v0_1_plan.json`](../native/CashFlowCore/Tests/CashFlowCoreTests/Fixtures/v0_1_plan.json). Tests verify decoding, integer money encoding, explicit-null overrides, recurrence expansion and the expected forecast result.
