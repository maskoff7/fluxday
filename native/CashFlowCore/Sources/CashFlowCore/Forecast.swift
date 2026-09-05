import Foundation

public struct ForecastDay: Equatable, Identifiable, Sendable {
  public var id: CalendarDate { date }

  public let date: CalendarDate
  public let openingBalanceMinor: Money
  public let incomeMinor: Money
  public let expenseMinor: Money
  public let netMinor: Money
  public let closingBalanceMinor: Money
  public let stressClosingBalanceMinor: Money
  public let occurrences: [Occurrence]
}

public struct CashGap: Equatable, Identifiable, Sendable {
  public var id: CalendarDate { startDate }

  public let startDate: CalendarDate
  public let recoveryDate: CalendarDate?
  public let lowestDate: CalendarDate
  public let lowestBalanceMinor: Money
  public let maximumDeficitMinor: Money
}

public struct Forecast: Equatable, Sendable {
  public let startDate: CalendarDate
  public let endDate: CalendarDate
  public let days: [ForecastDay]
  public let occurrences: [Occurrence]
  public let incomeMinor: Money
  public let expenseMinor: Money
  public let endingBalanceMinor: Money
  public let minimumBalanceMinor: Money
  public let minimumBalanceDate: CalendarDate
  public let maximumBalanceMinor: Money
  public let firstNegativeDate: CalendarDate?
  public let maximumDeficitMinor: Money
  public let stressEndingBalanceMinor: Money
  public let stressMinimumBalanceMinor: Money
  public let stressFirstNegativeDate: CalendarDate?
  public let cashGaps: [CashGap]
}

public enum ForecastEngine {
  public static func horizon(
    from startDate: CalendarDate,
    operations: [Operation]
  ) throws -> CalendarDate {
    var horizon = try startDate.adding(months: 6)
    let maximum = startDate.maximumPlanningDate

    for operation in operations where operation.enabled {
      let operationEnd =
        operation.recurrence == .none
        ? operation.firstDate
        : operation.recurrenceEndDate
      if let operationEnd, operationEnd > horizon { horizon = operationEnd }
    }

    return min(horizon, maximum)
  }

  public static func build(
    startingBalance: Money,
    startDate: CalendarDate,
    operations: [Operation],
    endDate: CalendarDate? = nil
  ) throws -> Forecast {
    let resolvedEndDate = try endDate ?? horizon(from: startDate, operations: operations)
    guard resolvedEndDate <= startDate.maximumPlanningDate else {
      throw CashFlowCoreError.planningHorizonTooLong
    }

    let occurrences = try RecurrenceEngine.expand(
      operations: operations,
      from: startDate,
      through: resolvedEndDate
    )
    let grouped = Dictionary(grouping: occurrences, by: \.date)

    var balance = startingBalance.minorUnits
    var stressBalance = startingBalance.minorUnits
    var minimumBalance = startingBalance.minorUnits
    var minimumBalanceDate = startDate
    var maximumBalance = startingBalance.minorUnits
    var stressMinimumBalance = startingBalance.minorUnits
    var firstNegativeDate: CalendarDate? = startingBalance.minorUnits < 0 ? startDate : nil
    var stressFirstNegativeDate: CalendarDate? = startingBalance.minorUnits < 0 ? startDate : nil
    var totalIncome: Int64 = 0
    var totalExpense: Int64 = 0
    var days: [ForecastDay] = []

    for date in try startDate.eachDay(through: resolvedEndDate) {
      let dayOccurrences = grouped[date] ?? []
      let openingBalance = balance
      var income: Int64 = 0
      var expense: Int64 = 0
      var expectedIncome: Int64 = 0

      for occurrence in dayOccurrences {
        switch occurrence.type {
        case .income:
          income = try checkedAdd(income, occurrence.amountMinor.minorUnits)
          if occurrence.certainty == .expected {
            expectedIncome = try checkedAdd(expectedIncome, occurrence.amountMinor.minorUnits)
          }
        case .expense:
          expense = try checkedAdd(expense, occurrence.amountMinor.minorUnits)
        }
      }

      let net = try checkedSubtract(income, expense)
      balance = try checkedAdd(balance, net)
      stressBalance = try checkedAdd(stressBalance, try checkedSubtract(net, expectedIncome))
      totalIncome = try checkedAdd(totalIncome, income)
      totalExpense = try checkedAdd(totalExpense, expense)

      if balance < minimumBalance {
        minimumBalance = balance
        minimumBalanceDate = date
      }
      maximumBalance = max(maximumBalance, balance)
      stressMinimumBalance = min(stressMinimumBalance, stressBalance)
      if balance < 0, firstNegativeDate == nil { firstNegativeDate = date }
      if stressBalance < 0, stressFirstNegativeDate == nil { stressFirstNegativeDate = date }

      days.append(
        ForecastDay(
          date: date,
          openingBalanceMinor: Money(minorUnits: openingBalance),
          incomeMinor: Money(minorUnits: income),
          expenseMinor: Money(minorUnits: expense),
          netMinor: Money(minorUnits: net),
          closingBalanceMinor: Money(minorUnits: balance),
          stressClosingBalanceMinor: Money(minorUnits: stressBalance),
          occurrences: dayOccurrences
        )
      )
    }

    let maximumDeficit = minimumBalance < 0 ? try checkedSubtract(0, minimumBalance) : 0

    return Forecast(
      startDate: startDate,
      endDate: resolvedEndDate,
      days: days,
      occurrences: occurrences,
      incomeMinor: Money(minorUnits: totalIncome),
      expenseMinor: Money(minorUnits: totalExpense),
      endingBalanceMinor: Money(minorUnits: balance),
      minimumBalanceMinor: Money(minorUnits: minimumBalance),
      minimumBalanceDate: minimumBalanceDate,
      maximumBalanceMinor: Money(minorUnits: maximumBalance),
      firstNegativeDate: firstNegativeDate,
      maximumDeficitMinor: Money(minorUnits: maximumDeficit),
      stressEndingBalanceMinor: Money(minorUnits: stressBalance),
      stressMinimumBalanceMinor: Money(minorUnits: stressMinimumBalance),
      stressFirstNegativeDate: stressFirstNegativeDate,
      cashGaps: try cashGaps(in: days)
    )
  }

  public static func compare(
    startingBalance: Money,
    startDate: CalendarDate,
    operations: [Operation],
    scenario: Scenario,
    endDate: CalendarDate? = nil
  ) throws -> ScenarioComparison {
    let resolvedEndDate = try endDate ?? horizon(from: startDate, operations: operations)
    let base = try build(
      startingBalance: startingBalance,
      startDate: startDate,
      operations: operations,
      endDate: resolvedEndDate
    )
    let scenarioForecast = try build(
      startingBalance: startingBalance,
      startDate: startDate,
      operations: ScenarioEngine.apply(scenario, to: operations),
      endDate: resolvedEndDate
    )
    return ScenarioComparison(
      base: base,
      scenario: scenarioForecast,
      endingBalanceDelta: Money(
        minorUnits: try checkedSubtract(
          scenarioForecast.endingBalanceMinor.minorUnits,
          base.endingBalanceMinor.minorUnits
        )
      ),
      minimumBalanceDelta: Money(
        minorUnits: try checkedSubtract(
          scenarioForecast.minimumBalanceMinor.minorUnits,
          base.minimumBalanceMinor.minorUnits
        )
      )
    )
  }

  private static func cashGaps(in days: [ForecastDay]) throws -> [CashGap] {
    var result: [CashGap] = []
    var start: CalendarDate?
    var lowestDate: CalendarDate?
    var lowestBalance: Int64 = 0

    for day in days {
      let balance = day.closingBalanceMinor.minorUnits
      if balance < 0 {
        if start == nil {
          start = day.date
          lowestDate = day.date
          lowestBalance = balance
        } else if balance < lowestBalance {
          lowestDate = day.date
          lowestBalance = balance
        }
      } else if let gapStart = start, let gapLowestDate = lowestDate {
        result.append(
          CashGap(
            startDate: gapStart,
            recoveryDate: day.date,
            lowestDate: gapLowestDate,
            lowestBalanceMinor: Money(minorUnits: lowestBalance),
            maximumDeficitMinor: Money(minorUnits: try checkedSubtract(0, lowestBalance))
          )
        )
        start = nil
        lowestDate = nil
      }
    }

    if let gapStart = start, let gapLowestDate = lowestDate {
      result.append(
        CashGap(
          startDate: gapStart,
          recoveryDate: nil,
          lowestDate: gapLowestDate,
          lowestBalanceMinor: Money(minorUnits: lowestBalance),
          maximumDeficitMinor: Money(minorUnits: try checkedSubtract(0, lowestBalance))
        )
      )
    }

    return result
  }
}
