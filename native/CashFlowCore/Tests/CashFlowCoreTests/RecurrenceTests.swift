import CashFlowCore
import XCTest

final class RecurrenceTests: XCTestCase {
  func testSuggestsTheV01DefaultSeriesEndDates() throws {
    let firstDate = try CalendarDate("2028-02-29")

    XCTAssertEqual(
      try RecurrenceEngine.defaultEndDate(from: firstDate, recurrence: .monthly),
      try CalendarDate("2028-03-29")
    )
    XCTAssertEqual(
      try RecurrenceEngine.defaultEndDate(from: firstDate, recurrence: .yearly),
      try CalendarDate("2029-02-28")
    )
    XCTAssertNil(try RecurrenceEngine.defaultEndDate(from: firstDate, recurrence: .none))
  }

  func testFindsTheNextAnchoredOccurrenceAndHonorsSeriesState() throws {
    let monthly = try operation(
      id: "rent",
      firstDate: "2025-01-31",
      recurrence: .monthly,
      recurrenceEndDate: "2025-05-31"
    )

    XCTAssertEqual(
      try RecurrenceEngine.nextOccurrenceDate(
        for: monthly,
        onOrAfter: CalendarDate("2025-02-01")
      ),
      try CalendarDate("2025-02-28")
    )
    XCTAssertNil(
      try RecurrenceEngine.nextOccurrenceDate(
        for: monthly,
        onOrAfter: CalendarDate("2025-06-01")
      )
    )

    var disabled = monthly
    disabled.enabled = false
    XCTAssertNil(
      try RecurrenceEngine.nextOccurrenceDate(
        for: disabled,
        onOrAfter: CalendarDate("2025-02-01")
      )
    )
  }

  func testAnchorsMonthEndWithoutDrift() throws {
    let item = try operation(
      id: "rent",
      firstDate: "2025-01-31",
      recurrence: .monthly,
      recurrenceEndDate: "2025-05-31"
    )
    XCTAssertEqual(
      try RecurrenceEngine.occurrenceDates(
        for: item,
        from: date("2025-01-01"),
        through: date("2025-05-31")
      ).map(\.description),
      ["2025-01-31", "2025-02-28", "2025-03-31", "2025-04-30", "2025-05-31"]
    )
  }

  func testJumpsToAnOldDailyAnchor() throws {
    let item = try operation(
      id: "daily",
      firstDate: "1900-01-01",
      recurrence: .daily,
      recurrenceEndDate: "2026-01-03"
    )
    XCTAssertEqual(
      try RecurrenceEngine.occurrenceDates(
        for: item,
        from: date("2026-01-01"),
        through: date("2026-01-03")
      ).map(\.description),
      ["2026-01-01", "2026-01-02", "2026-01-03"]
    )
  }

  func testMapsLeapDayYearlyRecurrenceToValidDates() throws {
    let item = try operation(
      id: "leap",
      firstDate: "2024-02-29",
      recurrence: .yearly,
      recurrenceEndDate: "2028-02-29"
    )
    XCTAssertEqual(
      try RecurrenceEngine.occurrenceDates(
        for: item,
        from: date("2024-01-01"),
        through: date("2028-12-31")
      ).map(\.description),
      ["2024-02-29", "2025-02-28", "2026-02-28", "2027-02-28", "2028-02-29"]
    )
  }

  func testExcludesDisabledAndExpiredSeries() throws {
    let disabled = try operation(
      id: "disabled",
      firstDate: "2026-01-01",
      recurrence: .weekly,
      recurrenceEndDate: "2026-02-01",
      enabled: false
    )
    XCTAssertTrue(
      try RecurrenceEngine.occurrenceDates(
        for: disabled,
        from: date("2026-01-01"),
        through: date("2026-02-01")
      ).isEmpty
    )
  }

  func testSupportsALongDailySeries() throws {
    let item = try operation(
      id: "daily",
      firstDate: "2020-01-01",
      recurrence: .daily,
      recurrenceEndDate: "2029-12-31"
    )
    let dates = try RecurrenceEngine.occurrenceDates(
      for: item,
      from: date("2020-01-01"),
      through: date("2029-12-31")
    )
    XCTAssertEqual(dates.count, 3_653)
    XCTAssertEqual(dates.last, try date("2029-12-31"))
  }
}
