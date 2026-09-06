import AppKit
import SwiftUI

@main
struct FluxdayApp: App {
  @AppStorage(AppLanguage.storageKey) private var languageIdentifier = AppLanguage.system.rawValue
  @StateObject private var model = AppModel()

  private var selectedLanguage: AppLanguage {
    AppLanguage(rawValue: languageIdentifier) ?? .system
  }

  init() {
    #if DEBUG
      let arguments = ProcessInfo.processInfo.arguments
      if arguments.contains("--light-appearance") {
        NSApplication.shared.appearance = NSAppearance(named: .aqua)
      } else if arguments.contains("--dark-appearance") {
        NSApplication.shared.appearance = NSAppearance(named: .darkAqua)
      }
    #endif
  }

  var body: some Scene {
    Window("app.name", id: "main") {
      ContentView()
        .environment(\.locale, selectedLanguage.locale)
        .environmentObject(model)
        .task { await model.start() }
    }
    .defaultSize(width: 1_080, height: 720)
    .commands {
      FluxdayCommands(locale: selectedLanguage.locale)
    }

    Settings {
      SettingsView()
        .environment(\.locale, selectedLanguage.locale)
        .environmentObject(model)
    }
  }
}
