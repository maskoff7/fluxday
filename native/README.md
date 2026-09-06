# Fluxday for macOS

This directory contains the production Fluxday application for macOS.

## Requirements

- macOS 14 or later
- Xcode 16 or later

## Build

```sh
xcodebuild \
  -project native/Fluxday.xcodeproj \
  -scheme Fluxday \
  -configuration Debug \
  -derivedDataPath native/.build/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Run the financial and persistence packages independently:

```sh
swift test --package-path native/CashFlowCore
swift test --package-path native/FluxdayPersistence
```

## Visual QA

The Debug build accepts `--demo` to display deterministic in-memory sample data without opening or writing either production database. Use `--demo-extremes` to exercise long names, large values, and negative balances. The `--light-appearance` and `--dark-appearance` flags make appearance QA deterministic without changing the system setting. These flags are only available in Debug builds.

![Native Fluxday planner in English](../docs/screenshots/native-planner.png)

![Native financial calendar in English](../docs/screenshots/native-calendar.png)

![Native cash flow summary in English](../docs/screenshots/native-summary.png)

![Native scenario comparison in English](../docs/screenshots/native-scenarios.png)
