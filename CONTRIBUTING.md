# Development guide

Fluxday keeps `main` releasable. Work in a focused branch, use Conventional Commits, open a pull request linked to an issue, and include English screenshots when interface behavior changes.

Before requesting review, run the relevant checks during development and one complete native gate for the finished increment:

```sh
swift format lint --recursive --strict native/Fluxday
swift format lint --strict native/CashFlowCore/Package.swift
swift format lint --recursive --strict native/CashFlowCore/Sources native/CashFlowCore/Tests
swift format lint --strict native/FluxdayPersistence/Package.swift
swift format lint --recursive --strict native/FluxdayPersistence/Sources native/FluxdayPersistence/Tests
swift test --package-path native/CashFlowCore
swift test --package-path native/FluxdayPersistence
xcodebuild \
  -project native/Fluxday.xcodeproj \
  -scheme Fluxday \
  -configuration Debug \
  -derivedDataPath native/.build/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Financial behavior belongs in `native/CashFlowCore` and requires focused regression tests. SQLite and migration work belongs in `native/FluxdayPersistence`. Keep SwiftUI and AppKit out of the financial core, treat imported data as untrusted, keep money in integer minor units, and keep financial dates free of timestamp and timezone conversions.

Prefer CLI tests, non-interactive rendering, and GitHub-hosted macOS checks. Group any necessary interactive window, menu, focus, hover, or accessibility QA into one pass before the pull request. Never add telemetry, network calls, or user financial data to the repository.
