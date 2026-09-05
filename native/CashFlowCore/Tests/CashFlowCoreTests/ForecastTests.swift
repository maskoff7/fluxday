import CashFlowCore
import XCTest

final class ForecastTests: XCTestCase {
  func testUsesTheClosingBalanceAfterAllOperationsInADay() throws {
    let forecast = try ForecastEngine.build(
      startingBalance: Money(minorUnits: 10_000),
      startDate: date("2026-01-01"),
      operations: [
        operation(id: "large-expense", amountMinor: 20_000),
        operation(id: "income", type: .income, amountMinor: 15_000),
      ],
      endDate: date("2026-01-03")
    )
    XCTAssertEqual(forecast.days[1].closingBalanceMinor.minorUnits, 5_000)
    XCTAssertNil(forecast.firstNegativeDate)
  }

  func testStressModeRemovesOnlyExpectedIncome() throws {
    let forecast = try ForecastEngine.build(
      startingBalance: Money(minorUnits: 2_000),
      startDate: date("2026-01-01"),
      operations: [
        operation(id: "expected-salary", type: .income, amountMinor: 10_000, certainty: .expected),
        operation(id: "expected-bill", amountMinor: 6_000, certainty: .expected),
      ],
      endDate: date("2026-01-03")
    )
    XCTAssertEqual(forecast.endingBalanceMinor.minorUnits, 6_000)
    XCTAssertEqual(forecast.stressEndingBalanceMinor.minorUnits, -4_000)
    XCTAssertEqual(forecast.stressFirstNegativeDate, try date("2026-01-02"))
    XCTAssertEqual(forecast.minimumBalanceMinor.minorUnits, 2_000)
  }

  func testDetectsAndExplainsARecoveringCashGap() throws {
    let forecast = try ForecastEngine.build(
      startingBalance: Money(minorUnits: 10_000),
      startDate: date("2026-01-01"),
      operations: [
        operation(id: "bill", amountMinor: 20_000, firstDate: "2026-01-02"),
        operation(id: "fee", amountMinor: 5_000, firstDate: "2026-01-03"),
        operation(id: "salary", type: .income, amountMinor: 20_000, firstDate: "2026-01-04"),
      ],
      endDate: date("2026-01-05")
    )
    XCTAssertEqual(forecast.cashGaps.count, 1)
    XCTAssertEqual(forecast.cashGaps[0].startDate, try date("2026-01-02"))
    XCTAssertEqual(forecast.cashGaps[0].recoveryDate, try date("2026-01-04"))
    XCTAssertEqual(forecast.cashGaps[0].lowestDate, try date("2026-01-03"))
    XCTAssertEqual(forecast.cashGaps[0].maximumDeficitMinor.minorUnits, 15_000)
  }

  func testRejectsUnsupportedHorizonAndArithmeticOverflow() throws {
    XCTAssertThrowsError(
      try ForecastEngine.build(
        startingBalance: .zero,
        startDate: date("2026-01-01"),
        operations: [],
        endDate: date("2200-01-01")
      )
    ) { error in
      XCTAssertEqual(error as? CashFlowCoreError, .planningHorizonTooLong)
    }

    XCTAssertThrowsError(
      try ForecastEngine.build(
        startingBalance: Money(minorUnits: .max),
        startDate: date("2026-01-01"),
        operations: [operation(id: "overflow", type: .income, amountMinor: 1)],
        endDate: date("2026-01-02")
      )
    ) { error in
      XCTAssertEqual(error as? CashFlowCoreError, .arithmeticOverflow)
    }
  }
}
