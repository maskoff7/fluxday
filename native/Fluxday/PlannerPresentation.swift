import CashFlowCore
import Foundation
import SwiftUI

extension Money {
  func formatted(locale: Locale, sign: String? = nil) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.currencyCode = "RUB"
    formatter.locale = locale
    formatter.minimumFractionDigits = 0
    formatter.maximumFractionDigits = 2
    let value = NSDecimalNumber(value: minorUnits).dividing(by: 100)
    let result = formatter.string(from: value) ?? "—"
    return sign.map { "\($0)\(result)" } ?? result
  }

  var chartValue: Double {
    Double(minorUnits) / 100
  }

  var inputValue: String {
    let absolute = Swift.abs(minorUnits)
    let whole = absolute / 100
    let fraction = absolute % 100
    let sign = minorUnits < 0 ? "-" : ""
    return fraction == 0
      ? "\(sign)\(whole)"
      : "\(sign)\(whole).\(String(format: "%02lld", fraction))"
  }
}

extension CalendarDate {
  var foundationDate: Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .autoupdatingCurrent
    return calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? .distantPast
  }

  func formatted(locale: Locale) -> String {
    foundationDate.formatted(
      Date.FormatStyle(date: .abbreviated, time: .omitted)
        .locale(locale)
    )
  }
}

extension Date {
  var calendarDate: CalendarDate {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .autoupdatingCurrent
    let components = calendar.dateComponents([.year, .month, .day], from: self)
    return try! CalendarDate(
      year: components.year ?? 2_000,
      month: components.month ?? 1,
      day: components.day ?? 1
    )
  }
}

extension OperationType {
  var titleKey: LocalizedStringKey {
    switch self {
    case .income: "operation.type.income"
    case .expense: "operation.type.expense"
    }
  }
}

extension Certainty {
  var titleKey: LocalizedStringKey {
    switch self {
    case .certain: "operation.certainty.certain"
    case .expected: "operation.certainty.expected"
    }
  }
}

extension Recurrence {
  var titleKey: LocalizedStringKey {
    switch self {
    case .none: "operation.recurrence.none"
    case .daily: "operation.recurrence.daily"
    case .weekly: "operation.recurrence.weekly"
    case .monthly: "operation.recurrence.monthly"
    case .yearly: "operation.recurrence.yearly"
    }
  }
}
