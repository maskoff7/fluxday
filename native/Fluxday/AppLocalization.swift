import Foundation

enum AppLocalization {
  static func string(_ key: String, locale: Locale) -> String {
    let language = locale.language.languageCode?.identifier == "ru" ? "ru" : "en"

    guard
      let path = Bundle.main.path(forResource: language, ofType: "lproj"),
      let bundle = Bundle(path: path)
    else {
      return key
    }

    return bundle.localizedString(forKey: key, value: key, table: nil)
  }

  static func format(_ key: String, locale: Locale, _ arguments: CVarArg...) -> String {
    String(format: string(key, locale: locale), locale: locale, arguments: arguments)
  }
}
