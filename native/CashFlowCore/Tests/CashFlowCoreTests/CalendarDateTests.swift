import CashFlowCore
import XCTest

final class CalendarDateTests: XCTestCase {
  func testValidatesGregorianDates() throws {
    XCTAssertEqual(try date("2024-02-29").description, "2024-02-29")
    XCTAssertThrowsError(try date("2025-02-29"))
    XCTAssertThrowsError(try date("2026-09-31"))
    XCTAssertThrowsError(try date("26-09-05"))
    XCTAssertThrowsError(try date("0999-12-31"))
  }

  func testKeepsTheOriginalMonthlyAnchor() throws {
    XCTAssertEqual(try date("2025-01-31").adding(months: 1), try date("2025-02-28"))
    XCTAssertEqual(try date("2025-01-31").adding(months: 2), try date("2025-03-31"))
    XCTAssertEqual(try date("2024-01-30").adding(months: 1), try date("2024-02-29"))
  }

  func testHandlesLeapYearsAndWeekBoundaries() throws {
    XCTAssertEqual(try date("2024-02-29").adding(years: 1), try date("2025-02-28"))
    XCTAssertEqual(try date("2025-12-31").adding(days: 1), try date("2026-01-01"))
    XCTAssertEqual(try date("2026-09-04").startOfWeek(), try date("2026-08-31"))
    XCTAssertEqual(try date("2026-09-04").endOfWeek(), try date("2026-09-06"))
  }

  func testRoundTripsAcrossTheSupportedRange() throws {
    let values = ["1000-01-01", "1900-03-01", "2000-02-29", "9999-12-31"]
    for value in values {
      let original = try date(value)
      XCTAssertEqual(try original.adding(days: 0), original)
    }
    XCTAssertThrowsError(try date("9999-12-31").adding(days: 1))
  }

  func testLimitsForecastDayExpansion() throws {
    let start = try date("2026-01-01")
    let lastAllowed = try start.adding(days: CalendarDate.maximumForecastDays - 1)
    XCTAssertEqual(try start.eachDay(through: lastAllowed).count, 40_000)
    XCTAssertThrowsError(try start.eachDay(through: lastAllowed.adding(days: 1)))
  }
}
