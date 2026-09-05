import Foundation

public enum ScenarioEngine {
  public static func apply(_ scenario: Scenario?, to operations: [Operation]) -> [Operation] {
    guard let scenario else { return operations }

    return operations.map { operation in
      guard operation.recurrence != .none, let override = scenario.overrides[operation.id] else {
        return operation
      }

      var result = operation
      if let amountMinor = override.amountMinor { result.amountMinor = amountMinor }
      if let recurrence = override.recurrence { result.recurrence = recurrence }
      if let firstDate = override.firstDate { result.firstDate = firstDate }
      if let recurrenceEndDate = override.recurrenceEndDate {
        result.recurrenceEndDate = recurrenceEndDate
      }
      if let certainty = override.certainty { result.certainty = certainty }
      if override.excluded == true { result.enabled = false }
      return result
    }
  }
}

public struct ScenarioComparison: Equatable, Sendable {
  public let base: Forecast
  public let scenario: Forecast
  public let endingBalanceDelta: Money
  public let minimumBalanceDelta: Money

  public init(
    base: Forecast,
    scenario: Forecast,
    endingBalanceDelta: Money,
    minimumBalanceDelta: Money
  ) {
    self.base = base
    self.scenario = scenario
    self.endingBalanceDelta = endingBalanceDelta
    self.minimumBalanceDelta = minimumBalanceDelta
  }
}
