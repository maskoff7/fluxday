import CashFlowCore
import FluxdayPersistence
import Foundation
import XCTest

final class PlanDocumentCodecTests: XCTestCase {
  func testExportRoundTripPreservesThePortablePlan() throws {
    let plan = try testPlan()
    let data = try PlanDocumentCodec.encode(
      plan,
      exportedAt: Date(timeIntervalSince1970: 0)
    )
    let decoded = try PlanDocumentCodec.decode(data)
    XCTAssertEqual(decoded, plan)

    let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    XCTAssertEqual(json["version"] as? Int, 4)
    XCTAssertEqual(json["product"] as? String, "Fluxday")
    XCTAssertEqual(json["exportedAt"] as? String, "1970-01-01T00:00:00.000Z")
    let operations = try XCTUnwrap(json["operations"] as? [[String: Any]])
    XCTAssertEqual(operations[0]["amountMinor"] as? Int, 50_025)
  }

  func testRejectsInvalidAndUnsupportedDocuments() throws {
    XCTAssertThrowsError(try PlanDocumentCodec.decode(Data("not-json".utf8))) { error in
      XCTAssertEqual(error as? PersistenceError, .invalidDocument)
    }

    var plan = try testPlan()
    plan.schemaVersion = 99
    let raw = try JSONEncoder().encode(plan)
    XCTAssertThrowsError(try PlanDocumentCodec.decode(raw)) { error in
      XCTAssertEqual(error as? PlanValidationError, .unsupportedSchemaVersion(99))
    }

    let oversized = Data(count: PlanDocumentCodec.maximumDocumentSize + 1)
    XCTAssertThrowsError(try PlanDocumentCodec.decode(oversized)) { error in
      XCTAssertEqual(error as? PersistenceError, .dataTooLarge)
    }
  }

  func testStorageLocationsKeepLegacyAndNativeDatabasesSeparate() throws {
    let directory = try StorageLocations.applicationSupportDirectory()
    XCTAssertEqual(
      try StorageLocations.legacyDatabaseURL(),
      directory.appendingPathComponent("fluxday.sqlite3")
    )
    XCTAssertEqual(
      try StorageLocations.nativeDatabaseURL(),
      directory.appendingPathComponent("fluxday-native.sqlite3")
    )
  }
}
