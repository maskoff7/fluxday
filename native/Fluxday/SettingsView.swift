import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
  @AppStorage(AppLanguage.storageKey) private var languageIdentifier = AppLanguage.system.rawValue
  @EnvironmentObject private var model: AppModel
  @Environment(\.locale) private var locale
  @State private var backupDocument: FluxdayBackupDocument?
  @State private var isPreparingBackup = false
  @State private var isRestoring = false
  @State private var showsExporter = false
  @State private var showsImporter = false
  @State private var confirmsRestore = false
  @State private var showsRestoreComplete = false
  @State private var showsTransferError = false

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

      Section {
        VStack(alignment: .leading, spacing: 10) {
          Button(action: prepareBackup) {
            Label("backup.create", systemImage: "externaldrive.badge.plus")
          }
          .disabled(isPreparingBackup || isRestoring || model.isLoading)

          Button {
            confirmsRestore = true
          } label: {
            Label("backup.restore", systemImage: "arrow.counterclockwise.circle")
          }
          .disabled(isPreparingBackup || isRestoring || model.isLoading)

          if isPreparingBackup || isRestoring {
            ProgressView()
              .controlSize(.small)
          }
        }
      } header: {
        Text("backup.section")
      } footer: {
        Text("backup.help")
      }
    }
    .formStyle(.grouped)
    .frame(width: 460, height: 400)
    .navigationTitle(AppLocalization.string("settings.title", locale: locale))
    .fileExporter(
      isPresented: $showsExporter,
      document: backupDocument,
      contentType: .json,
      defaultFilename: backupFilename,
      onCompletion: handleExport
    )
    .fileImporter(
      isPresented: $showsImporter,
      allowedContentTypes: [.json],
      allowsMultipleSelection: false,
      onCompletion: handleImport
    )
    .confirmationDialog(
      "backup.restore.confirm.title",
      isPresented: $confirmsRestore,
      titleVisibility: .visible
    ) {
      Button("backup.restore.confirm.action", role: .destructive) {
        showsImporter = true
      }
      Button("button.cancel", role: .cancel) {}
    } message: {
      Text("backup.restore.confirm.message")
    }
    .alert("backup.restore.complete.title", isPresented: $showsRestoreComplete) {
      Button("button.ok", role: .cancel) {}
    } message: {
      Text("backup.restore.complete.message")
    }
    .alert("backup.error.title", isPresented: $showsTransferError) {
      Button("button.ok", role: .cancel) {}
    } message: {
      Text("backup.error.message")
    }
  }

  private var backupFilename: String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd"
    return "Fluxday Backup \(formatter.string(from: Date()))"
  }

  private func prepareBackup() {
    isPreparingBackup = true
    Task {
      defer { isPreparingBackup = false }
      do {
        backupDocument = FluxdayBackupDocument(data: try await model.backupData())
        showsExporter = true
      } catch {
        presentTransferError(error)
      }
    }
  }

  private func handleExport(_ result: Result<URL, Error>) {
    backupDocument = nil
    if case .failure(let error) = result { presentTransferError(error) }
  }

  private func handleImport(_ result: Result<[URL], Error>) {
    switch result {
    case .success(let urls):
      guard let url = urls.first else { return }
      isRestoring = true
      Task {
        defer { isRestoring = false }
        do {
          try await model.restoreBackup(from: url)
          showsRestoreComplete = true
        } catch {
          presentTransferError(error)
        }
      }
    case .failure(let error):
      presentTransferError(error)
    }
  }

  private func presentTransferError(_ error: Error) {
    guard (error as NSError).code != NSUserCancelledError else { return }
    showsTransferError = true
  }
}

private struct FluxdayBackupDocument: FileDocument {
  static var readableContentTypes: [UTType] { [.json] }

  let data: Data

  init(data: Data) {
    self.data = data
  }

  init(configuration: ReadConfiguration) throws {
    guard let data = configuration.file.regularFileContents else {
      throw CocoaError(.fileReadCorruptFile)
    }
    self.data = data
  }

  func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
    FileWrapper(regularFileWithContents: data)
  }
}
