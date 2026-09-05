import CashFlowCore
import Foundation
import XCTest

final class PortableJSONTests: XCTestCase {
  func testDecodesTheV01GoldenPlan() throws {
    let url = try XCTUnwrap(Bundle.module.url(forResource: "v0_1_plan", withExtension: "json"))
    let data = try Data(contentsOf: url)
    let plan = try JSONDecoder().decode(CashFlowPlan.self, from: data)

    XCTAssertEqual(plan.schemaVersion, 1)
    XCTAssertEqual(plan.settings.startBalanceMinor.minorUnits, 123_456)
    XCTAssertEqual(plan.settings.startDate, try date("2026-01-01"))
    XCTAssertEqual(plan.operations[0].amountMinor.minorUnits, 50_025)
    XCTAssertEqual(plan.operations[0].recurrence, .monthly)
    XCTAssertEqual(plan.scenarios[0].overrides["rent"]?.amountMinor?.minorUnits, 70_050)

    let endOverride = try XCTUnwrap(plan.scenarios[0].overrides["rent"]?.recurrenceEndDate)
    XCTAssertNil(endOverride)

    let forecast = try ForecastEngine.build(
      startingBalance: plan.settings.startBalanceMinor,
      startDate: plan.settings.startDate,
      operations: plan.operations
    )
    XCTAssertEqual(forecast.endingBalanceMinor.minorUnits, -26_619)
    XCTAssertEqual(forecast.firstNegativeDate, try date("2026-03-31"))
  }

  func testRoundTripKeepsMinorUnitsAndExplicitNullOverride() throws {
    let url = try XCTUnwrap(Bundle.module.url(forResource: "v0_1_plan", withExtension: "json"))
    let original = try JSONDecoder().decode(CashFlowPlan.self, from: Data(contentsOf: url))
    let encoded = try JSONEncoder().encode(original)
    let roundTrip = try JSONDecoder().decode(CashFlowPlan.self, from: encoded)
    XCTAssertEqual(roundTrip, original)

    let json = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
    let operations = try XCTUnwrap(json["operations"] as? [[String: Any]])
    XCTAssertEqual(operations[0]["amountMinor"] as? Int, 50_025)
    let scenarios = try XCTUnwrap(json["scenarios"] as? [[String: Any]])
    let overrides = try XCTUnwrap(scenarios[0]["overrides"] as? [String: [String: Any]])
    XCTAssertTrue(overrides["rent"]?["recurrenceEndDate"] is NSNull)
  }
}
