import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
  static let storageKey = "appLanguage"

  case system
  case english = "en"
  case russian = "ru"

  var id: String { rawValue }

  var locale: Locale {
    switch self {
    case .system:
      .autoupdatingCurrent
    case .english:
      Locale(identifier: "en")
    case .russian:
      Locale(identifier: "ru")
    }
  }

  var label: LocalizedStringKey {
    switch self {
    case .system:
      "language.system"
    case .english:
      "language.english"
    case .russian:
      "language.russian"
    }
  }
}
