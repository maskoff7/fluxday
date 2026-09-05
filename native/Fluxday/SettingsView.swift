import SwiftUI

struct SettingsView: View {
  @AppStorage(AppLanguage.storageKey) private var languageIdentifier = AppLanguage.system.rawValue
  @Environment(\.locale) private var locale

  var body: some View {
    Form {
      Section {
        Picker("settings.language.label", selection: $languageIdentifier) {
          ForEach(AppLanguage.allCases) { language in
            Text(language.label)
              .tag(language.rawValue)
          }
        }
        .pickerStyle(.radioGroup)
      } header: {
        Text("settings.language.section")
      } footer: {
        Text("settings.language.help")
      }
    }
    .formStyle(.grouped)
    .frame(width: 420, height: 230)
    .navigationTitle(AppLocalization.string("settings.title", locale: locale))
  }
}
