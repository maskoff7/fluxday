import CashFlowCore
import Foundation

public enum PlanDocumentCodec {
  public static func decode(_ data: Data) throws -> CashFlowPlan {
    do {
      let plan = try JSONDecoder().decode(CashFlowPlan.self, from: data)
      try PlanValidator.validate(plan)
      return plan
    } catch let error as PlanValidationError {
      throw error
    } catch {
      throw PersistenceError.invalidDocument
    }
  }

  public static func encode(
    _ plan: CashFlowPlan,
    exportedAt: Date = Date()
  ) throws -> Data {
    try PlanValidator.validate(plan)
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    let document = PlanDocument(
      version: 4,
      product: "Fluxday",
      exportedAt: formatter.string(from: exportedAt),
      plan: plan
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    return try encoder.encode(document)
  }
}

private struct PlanDocument: Encodable {
  let version: Int
  let product: String
  let exportedAt: String
  let schemaVersion: Int
  let settings: PlanSettings
  let operations: [CashFlowCore.Operation]
  let scenarios: [Scenario]

  init(version: Int, product: String, exportedAt: String, plan: CashFlowPlan) {
    self.version = version
    self.product = product
    self.exportedAt = exportedAt
    schemaVersion = plan.schemaVersion
    settings = plan.settings
    operations = plan.operations
    scenarios = plan.scenarios
  }
}
