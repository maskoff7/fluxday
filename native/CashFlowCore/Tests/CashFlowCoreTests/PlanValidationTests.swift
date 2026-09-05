import CashFlowCore
import XCTest

final class PlanValidationTests: XCTestCase {
  func testAcceptsAValidPlan() throws {
    let plan = CashFlowPlan(
      settings: PlanSettings(
        startBalanceMinor: Money(minorUnits: 1_000),
        startDate: try CalendarDate("2026-01-01")
      ),
      operations: [
        try operation(
          id: "rent",
          recurrence: .monthly,
          recurrenceEndDate: "2026-12-31"
        )
      ],
      scenarios: [Scenario(id: "higher-rent", name: "Higher rent")]
    )

    XCTAssertNoThrow(try PlanValidator.validate(plan))
  }

  func testRejectsARecurringSeriesEndingBeforeItStarts() throws {
    let recurring = try operation(
      id: "rent",
      recurrence: .monthly,
      recurrenceEndDate: "2025-12-31"
    )
    let plan = CashFlowPlan(
      settings: PlanSettings(
        startBalanceMinor: .zero,
        startDate: try CalendarDate("2026-01-01")
      ),
      operations: [recurring]
    )

    XCTAssertThrowsError(try PlanValidator.validate(plan)) { error in
      XCTAssertEqual(error as? PlanValidationError, .invalidRecurrenceEnd("rent"))
    }
  }

  func testRejectsARecurringSeriesWithoutAnEndDate() throws {
    let recurring = try operation(id: "rent", recurrence: .monthly)
    let plan = CashFlowPlan(
      settings: PlanSettings(
        startBalanceMinor: .zero,
        startDate: try CalendarDate("2026-01-01")
      ),
      operations: [recurring]
    )

    XCTAssertThrowsError(try PlanValidator.validate(plan)) { error in
      XCTAssertEqual(error as? PlanValidationError, .invalidRecurrenceEnd("rent"))
    }
  }

  func testRejectsARecurringSeriesBeyondThePlanningHorizon() throws {
    let recurring = try operation(
      id: "rent",
      recurrence: .yearly,
      recurrenceEndDate: "2126-01-03"
    )
    let plan = CashFlowPlan(
      settings: PlanSettings(
        startBalanceMinor: .zero,
        startDate: try CalendarDate("2026-01-01")
      ),
      operations: [recurring]
    )

    XCTAssertThrowsError(try PlanValidator.validate(plan)) { error in
      XCTAssertEqual(error as? PlanValidationError, .invalidRecurrenceEnd("rent"))
    }
  }

  func testRejectsDuplicateScenarioIdentifiers() throws {
    let plan = CashFlowPlan(
      settings: PlanSettings(
        startBalanceMinor: .zero,
        startDate: try CalendarDate("2026-01-01")
      ),
      scenarios: [
        Scenario(id: "baseline", name: "First"),
        Scenario(id: "baseline", name: "Second"),
      ]
    )

    XCTAssertThrowsError(try PlanValidator.validate(plan)) { error in
      XCTAssertEqual(error as? PlanValidationError, .duplicateScenarioID("baseline"))
    }
  }
}
