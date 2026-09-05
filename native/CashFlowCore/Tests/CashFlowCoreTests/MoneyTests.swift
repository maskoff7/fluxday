import CashFlowCore
import XCTest

final class MoneyTests: XCTestCase {
  func testParsesMinorUnitsWithoutFloatingPointRounding() {
    XCTAssertEqual(Money.parse("12 345,67")?.minorUnits, 1_234_567)
    XCTAssertEqual(Money.parse("0.10")?.minorUnits, 10)
    XCTAssertEqual(Money.parse("42.")?.minorUnits, 4_200)
  }

  func testEnforcesInputBoundariesAndSignPolicy() {
    XCTAssertEqual(
      Money.parse("100000000")?.minorUnits,
      Money.maximumInputMinorUnits
    )
    XCTAssertNil(Money.parse("100000000.01"))
    XCTAssertNil(Money.parse("-1.00"))
    XCTAssertEqual(Money.parse("-1.00", allowNegative: true)?.minorUnits, -100)
    XCTAssertNil(Money.parse("1.001"))
    XCTAssertNil(Money.parse("NaN"))
  }

  func testMoneyEncodesAsTheV01IntegerContract() throws {
    let data = try JSONEncoder().encode(Money(minorUnits: 12_345))
    XCTAssertEqual(String(decoding: data, as: UTF8.self), "12345")
    XCTAssertEqual(try JSONDecoder().decode(Money.self, from: data).minorUnits, 12_345)
  }
}
