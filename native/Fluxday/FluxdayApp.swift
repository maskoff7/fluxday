import SwiftUI

@main
struct FluxdayApp: App {
  @AppStorage(AppLanguage.storageKey) private var languageIdentifier = AppLanguage.system.rawValue
  @StateObject private var model = AppModel()

  private var selectedLanguage: AppLanguage {
    AppLanguage(rawValue: languageIdentifier) ?? .system
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
        .environment(\.locale, selectedLanguage.locale)
        .environmentObject(model)
        .task { await model.start() }
    }
    .defaultSize(width: 1_080, height: 720)

    Settings {
      SettingsView()
        .environment(\.locale, selectedLanguage.locale)
    }
  }
}
