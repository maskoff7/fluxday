import CashFlowCore
import XCTest

final class ScenarioSummaryTests: XCTestCase {
  func testAppliesSparseRecurringOverridesWithoutMutatingTheBase() throws {
    let base = try operation(
      id: "rent",
      amountMinor: 5_000_000,
      firstDate: "2026-01-10",
      recurrence: .monthly,
      recurrenceEndDate: "2026-12-10"
    )
    let scenario = Scenario(
      id: "higher",
      name: "Higher rent",
      overrides: ["rent": ScenarioOverride(amountMinor: Money(minorUnits: 7_000_000))]
    )
    let result = ScenarioEngine.apply(scenario, to: [base])
    XCTAssertEqual(result[0].amountMinor.minorUnits, 7_000_000)
    XCTAssertEqual(base.amountMinor.minorUnits, 5_000_000)
  }

  func testIgnoresOverridesForOneTimeOperations() throws {
    let base = try operation(id: "one-time", amountMinor: 10_000)
    let scenario = Scenario(
      id: "ignored",
      name: "Ignored",
      overrides: ["one-time": ScenarioOverride(amountMinor: Money(minorUnits: 99_000))]
    )
    XCTAssertEqual(ScenarioEngine.apply(scenario, to: [base]), [base])
  }

  func testExcludesARecurringSeriesWithoutMutatingItsBaseState() throws {
    let base = try operation(
      id: "rent",
      firstDate: "2026-01-01",
      recurrence: .monthly,
      recurrenceEndDate: "2026-03-01"
    )
    let scenario = Scenario(
      id: "without-rent",
      name: "Without rent",
      overrides: ["rent": ScenarioOverride(excluded: true)]
    )

    let result = ScenarioEngine.apply(scenario, to: [base])

    XCTAssertFalse(result[0].enabled)
    XCTAssertTrue(base.enabled)
  }

  func testBuildsScenarioComparisonAnalytics() throws {
    let rent = try operation(
      id: "rent",
      amountMinor: 10_000,
      firstDate: "2026-01-01",
      recurrence: .monthly,
      recurrenceEndDate: "2026-02-01"
    )
    let scenario = Scenario(
      id: "lower",
      name: "Lower rent",
      overrides: ["rent": ScenarioOverride(amountMinor: Money(minorUnits: 8_000))]
    )
    let comparison = try ForecastEngine.compare(
      startingBalance: Money(minorUnits: 50_000),
      startDate: date("2026-01-01"),
      operations: [rent],
      scenario: scenario,
      endDate: date("2026-02-01")
    )
    XCTAssertEqual(comparison.endingBalanceDelta.minorUnits, 4_000)
    XCTAssertEqual(comparison.minimumBalanceDelta.minorUnits, 4_000)
  }

  func testAggregatesRecurringOccurrencesBySourceOperation() throws {
    let weekly = try operation(
      id: "weekly",
      amountMinor: 1_000,
      firstDate: "2026-01-01",
      recurrence: .weekly,
      recurrenceEndDate: "2026-01-31"
    )
    let summary = try SummaryEngine.build(
      operations: [weekly],
      from: date("2026-01-01"),
      through: date("2026-01-31")
    )
    XCTAssertEqual(summary.occurrenceCount, 5)
    XCTAssertEqual(summary.expenseMinor.minorUnits, 5_000)
    XCTAssertEqual(summary.groups[0].count, 5)
    XCTAssertEqual(summary.groups[0].totalMinor.minorUnits, 5_000)
    XCTAssertEqual(summary.groups[0].share, 1)
  }

  func testFiltersCompositionWithoutChangingPeriodTotals() throws {
    let income = try operation(
      id: "salary",
      type: .income,
      amountMinor: 20_000,
      firstDate: "2026-01-02"
    )
    let expense = try operation(
      id: "rent",
      amountMinor: 5_000,
      firstDate: "2026-01-03"
    )

    let summary = try SummaryEngine.build(
      operations: [income, expense],
      from: date("2026-01-01"),
      through: date("2026-01-31"),
      filter: .expense
    )

    XCTAssertEqual(summary.incomeMinor.minorUnits, 20_000)
    XCTAssertEqual(summary.expenseMinor.minorUnits, 5_000)
    XCTAssertEqual(summary.netMinor.minorUnits, 15_000)
    XCTAssertEqual(summary.groups.map(\.id), ["rent"])
    XCTAssertEqual(summary.groups[0].share, 1)
  }
}
