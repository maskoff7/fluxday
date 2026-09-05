import Foundation

public struct Money: RawRepresentable, Codable, Hashable, Comparable, Sendable {
  public static let zero = Money(minorUnits: 0)
  public static let maximumInputMinorUnits: Int64 = 10_000_000_000

  public let rawValue: Int64

  public var minorUnits: Int64 { rawValue }

  public init(rawValue: Int64) {
    self.rawValue = rawValue
  }

  public init(minorUnits: Int64) {
    rawValue = minorUnits
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    rawValue = try container.decode(Int64.self)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(rawValue)
  }

  public static func < (left: Money, right: Money) -> Bool {
    left.rawValue < right.rawValue
  }

  public static func parse(_ input: String, allowNegative: Bool = false) -> Money? {
    let compact = input.unicodeScalars.filter {
      !CharacterSet.whitespacesAndNewlines.contains($0) && $0.value != 0x00A0
    }
    var value = String(String.UnicodeScalarView(compact)).replacingOccurrences(of: ",", with: ".")
    let isNegative = value.first == "-"

    if isNegative {
      guard allowNegative else { return nil }
      value.removeFirst()
    }

    let parts = value.split(separator: ".", omittingEmptySubsequences: false)
    guard
      parts.count <= 2,
      let wholeText = parts.first,
      !wholeText.isEmpty,
      wholeText.allSatisfy(\.isNumber),
      let whole = Int64(wholeText)
    else {
      return nil
    }

    let fractionText = parts.count == 2 ? parts[1] : ""
    guard fractionText.count <= 2, fractionText.allSatisfy(\.isNumber) else { return nil }

    let paddedFraction = fractionText + String(repeating: "0", count: 2 - fractionText.count)
    let fraction = Int64(paddedFraction) ?? 0
    let (scaledWhole, multiplyOverflow) = whole.multipliedReportingOverflow(by: 100)
    let (absoluteMinorUnits, addOverflow) = scaledWhole.addingReportingOverflow(fraction)

    guard
      !multiplyOverflow,
      !addOverflow,
      absoluteMinorUnits <= maximumInputMinorUnits
    else {
      return nil
    }

    return Money(minorUnits: isNegative ? -absoluteMinorUnits : absoluteMinorUnits)
  }
}

public enum CashFlowCoreError: Error, Equatable, Sendable {
  case arithmeticOverflow
  case forecastRangeTooLarge
  case planningHorizonTooLong
  case tooManyOccurrences(operationID: String)
}

func checkedAdd(_ left: Int64, _ right: Int64) throws -> Int64 {
  let (result, overflow) = left.addingReportingOverflow(right)
  guard !overflow else { throw CashFlowCoreError.arithmeticOverflow }
  return result
}

func checkedSubtract(_ left: Int64, _ right: Int64) throws -> Int64 {
  let (result, overflow) = left.subtractingReportingOverflow(right)
  guard !overflow else { throw CashFlowCoreError.arithmeticOverflow }
  return result
}
