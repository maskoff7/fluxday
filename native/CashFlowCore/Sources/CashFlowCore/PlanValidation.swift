import Foundation

public enum PlanValidator {
  public static func validate(_ plan: CashFlowPlan) throws {
    guard plan.schemaVersion == 1 else {
      throw PlanValidationError.unsupportedSchemaVersion(plan.schemaVersion)
    }
    guard plan.settings.baseCurrency == "RUB" else {
      throw PlanValidationError.unsupportedCurrency(plan.settings.baseCurrency)
    }
    guard
      (-Money.maximumInputMinorUnits...Money.maximumInputMinorUnits).contains(
        plan.settings.startBalanceMinor.minorUnits
      )
    else {
      throw PlanValidationError.startBalanceOutOfRange
    }

    var operationIDs = Set<String>()
    for operation in plan.operations {
      guard isSafeID(operation.id) else {
        throw PlanValidationError.invalidOperationID(operation.id)
      }
      guard operationIDs.insert(operation.id).inserted else {
        throw PlanValidationError.duplicateOperationID(operation.id)
      }
      guard
        operation.name == operation.name.trimmingCharacters(in: .whitespacesAndNewlines),
        !operation.name.isEmpty,
        operation.name.count <= 160
      else {
        throw PlanValidationError.invalidOperationName(operation.id)
      }
      guard
        (1...Money.maximumInputMinorUnits).contains(operation.amountMinor.minorUnits)
      else {
        throw PlanValidationError.invalidOperationAmount(operation.id)
      }
      guard operation.note.count <= 500 else {
        throw PlanValidationError.operationNoteTooLong(operation.id)
      }
      let hasValidEndDate =
        operation.recurrenceEndDate.map({ $0 >= operation.firstDate }) ?? true
      guard operation.recurrence != .none || operation.recurrenceEndDate == nil,
        hasValidEndDate
      else {
        throw PlanValidationError.invalidRecurrenceEnd(operation.id)
      }
    }

    var scenarioIDs = Set<String>()
    for scenario in plan.scenarios {
      guard isSafeID(scenario.id) else {
        throw PlanValidationError.invalidScenarioID(scenario.id)
      }
      guard scenarioIDs.insert(scenario.id).inserted else {
        throw PlanValidationError.duplicateScenarioID(scenario.id)
      }
      guard
        scenario.name == scenario.name.trimmingCharacters(in: .whitespacesAndNewlines),
        !scenario.name.isEmpty,
        scenario.name.count <= 80
      else {
        throw PlanValidationError.invalidScenarioName(scenario.id)
      }
      for (operationID, override) in scenario.overrides {
        guard operationIDs.contains(operationID) else {
          throw PlanValidationError.orphanScenarioOverride(operationID)
        }
        if let amount = override.amountMinor?.minorUnits,
          !(1...Money.maximumInputMinorUnits).contains(amount)
        {
          throw PlanValidationError.invalidScenarioAmount(operationID)
        }
      }
    }
  }

  private static func isSafeID(_ value: String) -> Bool {
    !value.isEmpty
      && value.unicodeScalars.allSatisfy {
        (48...57).contains($0.value)
          || (65...90).contains($0.value)
          || (97...122).contains($0.value)
          || $0.value == 45 || $0.value == 95
      }
  }
}

public enum PlanValidationError: Error, Equatable, Sendable {
  case unsupportedSchemaVersion(Int)
  case unsupportedCurrency(String)
  case startBalanceOutOfRange
  case invalidOperationID(String)
  case duplicateOperationID(String)
  case invalidOperationName(String)
  case invalidOperationAmount(String)
  case operationNoteTooLong(String)
  case invalidRecurrenceEnd(String)
  case invalidScenarioID(String)
  case duplicateScenarioID(String)
  case invalidScenarioName(String)
  case orphanScenarioOverride(String)
  case invalidScenarioAmount(String)
}
